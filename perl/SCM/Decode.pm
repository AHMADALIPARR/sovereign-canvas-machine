# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

package SCM::Decode;
use strict;
use warnings;
use IPC::Open3;
use Symbol qw(gensym);
use Exporter 'import';
our @EXPORT_OK = qw(decode awk_decode fields_canon);

my $CHARSET = qr{[^A-Za-z0-9 :_./-]};

sub fail {
    my ($code) = @_;
    return { ok => 0, error => $code, fields => {} };
}

sub decode {
    my ($text) = @_;
    $text = '' unless defined $text;
    return fail('TRUNCATED') if $text eq '';
    return fail('METACHAR') if $text =~ /\r/;
    my @lines = split /\n/, $text, -1;
    pop @lines if @lines && $lines[-1] eq '';
    return fail('TRUNCATED') unless @lines;

    my $size = 0;
    my %f;
    my $state = 'NEED_HEADER';
    my $ws    = '';
    my $order = 0;
    my $nq    = 0;

    for my $line (@lines) {
        return fail('LINE_TOO_LONG') if length($line) > 512;
        return fail('BAD_WHITESPACE') if $line =~ /^[ ]/ || $line =~ /[ ]$/ || $line eq '';
        return fail('METACHAR') if $line =~ $CHARSET;
        $size += length($line) + 1;
        return fail('RECORD_TOO_LARGE') if $size > 4096;

        if ($state eq 'NEED_HEADER') {
            return fail('MISSING_HEADER') unless $line eq 'SCM-CANVAS/1.0';
            $f{protocol} = 'SCM-CANVAS/1.0';
            $state = 'NEED_INTENT';
            next;
        }
        if ($state eq 'NEED_INTENT') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^INTENT /;
            my $id = substr($line, 7);
            return fail('BAD_INTENT')
                unless $id =~ /^SCM-[A-Z0-9]+(?:-[A-Z0-9]+)*$/ && length($id) <= 64;
            $f{intent} = $id;
            $state = 'NEED_WORKSPACE';
            next;
        }
        if ($state eq 'NEED_WORKSPACE') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^WORKSPACE /;
            my $w = substr($line, 10);
            return fail('UNKNOWN_WORKSPACE')
                unless $w eq 'BRAID' || $w eq 'QUANTUM' || $w eq 'RECURRENCE';
            $f{workspace} = $w;
            $ws = $w;
            $state = 'NEED_STATUS';
            next;
        }
        if ($state eq 'NEED_STATUS') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^STATUS /;
            my $st = substr($line, 7);
            return fail('BAD_STATUS') unless $st eq 'UNVERIFIED';
            $f{status} = $st;
            $state = $ws eq 'BRAID' ? 'NEED_TARGET'
                   : $ws eq 'QUANTUM' ? 'NEED_QUBITS'
                   : 'NEED_ORDER';
            next;
        }
        if ($state eq 'NEED_QUBITS') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^QUBITS /;
            my $q = substr($line, 7);
            return fail('BAD_QUBITS') unless $q =~ /^[1-4]$/;
            $f{qubits} = $q;
            $nq = $q + 0;
            $state = 'NEED_TARGET';
            next;
        }
        if ($state eq 'NEED_ORDER') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^ORDER /;
            my $k = substr($line, 6);
            return fail('BAD_ORDER') unless $k =~ /^[1-6]$/;
            $f{order} = $k;
            $order = $k + 0;
            $state = 'NEED_COEFFS';
            next;
        }
        if ($state eq 'NEED_COEFFS') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^COEFFS /;
            my $body = substr($line, 7);
            return fail('BAD_COEFFS') unless _ints($body, $order, -20, 20);
            $f{coeffs} = $body;
            $state = 'NEED_INITIAL';
            next;
        }
        if ($state eq 'NEED_INITIAL') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^INITIAL /;
            my $body = substr($line, 8);
            return fail('BAD_INITIAL') unless _ints($body, $order, -1000000000, 1000000000);
            $f{initial} = $body;
            $state = 'NEED_INDEX';
            next;
        }
        if ($state eq 'NEED_INDEX') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^TARGET_INDEX /;
            my $n = substr($line, 13);
            return fail('BAD_INDEX') unless $n =~ /^\d+$/ && $n <= 30;
            $f{target_index} = $n;
            $state = 'NEED_TARGET_VALUE';
            next;
        }
        if ($state eq 'NEED_TARGET_VALUE') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^TARGET_VALUE /;
            my $v = substr($line, 13);
            return fail('BAD_TARGET_VALUE') unless _ints($v, 1, -1000000000, 1000000000);
            $f{target_value} = $v;
            $state = 'NEED_CANDIDATE_VALUE';
            next;
        }
        if ($state eq 'NEED_CANDIDATE_VALUE') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^CANDIDATE_VALUE /;
            my $v = substr($line, 16);
            return fail('BAD_CANDIDATE_VALUE') unless _ints($v, 1, -1000000000, 1000000000);
            $f{candidate_value} = $v;
            $state = 'NEED_COST';
            next;
        }
        if ($state eq 'NEED_TARGET') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^TARGET /;
            my $body = substr($line, 7);
            if ($ws eq 'BRAID') {
                return fail('BAD_TARGET') unless _gens($body);
            } else {
                return fail('BAD_TARGET') unless _gates($body, $nq);
            }
            $f{target} = $body;
            $state = 'NEED_CANDIDATE';
            next;
        }
        if ($state eq 'NEED_CANDIDATE') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^CANDIDATE /;
            my $body = substr($line, 10);
            if ($ws eq 'BRAID') {
                return fail('BAD_CANDIDATE') unless _gens($body);
            } else {
                return fail('BAD_CANDIDATE') unless _gates($body, $nq);
            }
            $f{candidate} = $body;
            $state = 'NEED_COST';
            next;
        }
        if ($state eq 'NEED_COST') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^COST /;
            my $c = substr($line, 5);
            return fail('BAD_COST') unless $c =~ /^[1-9][0-9]*$/ && $c <= 32;
            $f{cost} = $c;
            $state = 'NEED_TRANSFORMATIONS';
            next;
        }
        if ($state eq 'NEED_TRANSFORMATIONS') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^TRANSFORMATIONS /;
            my $t = substr($line, 16);
            return fail('BAD_TRANSFORMATIONS') unless $t =~ /^\d+$/ && $t <= 32;
            $f{transformations} = $t;
            $state = 'NEED_OBLIGATIONS';
            next;
        }
        if ($state eq 'NEED_OBLIGATIONS') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^PROOF_OBLIGATIONS /;
            my $body = substr($line, 18);
            return fail('BAD_OBLIGATIONS') unless $body =~ /^[A-Z][A-Z]-[0-9][0-9][0-9](?: [A-Z][A-Z]-[0-9][0-9][0-9])*$/;
            my @ids = split / /, $body;
            return fail('BAD_OBLIGATIONS') if @ids > 8;
            $f{proof_obligations} = $body;
            $state = 'NEED_RESOURCE';
            next;
        }
        if ($state eq 'NEED_RESOURCE') {
            return fail('BAD_FIELD_ORDER') unless $line =~ /^RESOURCE_ESTIMATE /;
            my $body = substr($line, 18);
            return fail('BAD_RESOURCE') unless $body =~ /^(\d+) (\d+)$/;
            my ($cy, $mem) = ($1, $2);
            return fail('BAD_RESOURCE') if $cy < 1 || $cy > 100000 || $mem < 1 || $mem > 1048576;
            $f{cycles} = $cy;
            $f{memory} = $mem;
            $state = 'NEED_END';
            next;
        }
        if ($state eq 'NEED_END') {
            return fail('UNKNOWN_LINE') unless $line eq 'END';
            $f{decode} = 'OK';
            $state = 'DONE';
            next;
        }
        return fail('UNKNOWN_LINE');
    }
    return fail('TRUNCATED') unless $state eq 'DONE';
    return { ok => 1, error => '', fields => \%f };
}

sub _ints {
    my ($s, $expect, $lo, $hi) = @_;
    my @a = split / /, $s;
    return 0 unless @a == $expect;
    for my $v (@a) {
        return 0 unless $v =~ /^-?\d+$/;
        return 0 if length($v) > 1 && $v =~ /^-?0/;
        return 0 if $v < $lo || $v > $hi;
    }
    return 1;
}

sub _gens {
    my ($s) = @_;
    my @a = split / /, $s;
    return 0 unless @a >= 1 && @a <= 12;
    for my $g (@a) {
        return 0 unless $g eq 's1' || $g eq 's2' || $g eq 's1_inv' || $g eq 's2_inv';
    }
    return 1;
}

sub _gates {
    my ($s, $nq) = @_;
    my @a = split / /, $s;
    return 0 unless @a >= 1 && @a <= 32;
    for my $g (@a) {
        if ($g =~ /^(H|X|Y|Z|S|SDG):(\d+)$/) {
            return 0 if $2 >= $nq;
        } elsif ($g =~ /^(CNOT|CZ):(\d+):(\d+)$/) {
            return 0 if $2 == $3 || $2 >= $nq || $3 >= $nq;
        } else {
            return 0;
        }
    }
    return 1;
}

sub awk_decode {
    my ($root, $text) = @_;
    my $script = "$root/awk/canvas_decoder.awk";
    my $err = gensym;
    my $pid = open3(my $in, my $out, $err, 'awk', '-f', $script);
    print {$in} $text;
    close $in;
    my $data = do { local $/; <$out> };
    my $awkerr = do { local $/; <$err> };
    waitpid($pid, 0);
    my $code = $? >> 8;
    my %f;
    my $error = '';
    for my $line (split /\n/, $data // '') {
        if ($line =~ /^ERROR:(.*)\z/) { $error = $1 }
        elsif ($line =~ /^([^=]+)=(.*)\z/) { $f{$1} = $2 }
    }
    if ($error ne '') {
        return { ok => 0, error => $error, fields => {}, stderr => $awkerr // '' };
    }
    if ($code != 0) {
        return { ok => 0, error => 'AWK_FAIL', fields => {}, stderr => $awkerr // '' };
    }
    return { ok => 1, error => '', fields => \%f, stderr => $awkerr // '' };
}

sub fields_canon {
    my ($fields) = @_;
    my @keys = sort keys %$fields;
    return join "\n", map { "$_=$fields->{$_}" } @keys;
}

1;
