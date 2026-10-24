# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

package SCM::Pipeline;
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use File::Spec;
use File::Temp qw(tempdir);
use SCM::Decode qw(decode awk_decode fields_canon);
use SCM::Policy qw(decide);
use SCM::Optimize qw(bound);
use SCM::HyperDAG qw(build);
use SCM::Braid qw(parse_gens invariant);
use SCM::Quantum qw(parse_gates tableau_key);
use SCM::ADR qw(check);
use SCM::Ledger qw(append);

use Exporter 'import';
our @EXPORT_OK = qw(run);

my %GATE_OP = (
    H => 1, X => 2, Y => 3, Z => 4, S => 5, SDG => 6, CNOT => 7, CZ => 8,
);

sub run {
    my ($text, %opt) = @_;
    my @trace;
    my $root = $opt{root} // $ENV{SCM_ROOT} // _root();
    local $ENV{SCM_ROOT} = $root;

    my $perl = decode($text);
    my $awk  = awk_decode($root, $text);
    if (!$perl->{ok} || !$awk->{ok}) {
        if (!$perl->{ok} && !$awk->{ok} && $perl->{error} ne $awk->{error}) {
            return _rej('DECODER_MISMATCH', \@trace);
        }
        my $code = !$perl->{ok} ? $perl->{error} : $awk->{error};
        return _rej($code, \@trace);
    }
    if (fields_canon($perl->{fields}) ne fields_canon($awk->{fields})) {
        return _rej('DECODER_MISMATCH', \@trace);
    }
    push @trace, 'decode=OK';
    my $f = $perl->{fields};

    my ($adr_ok, $adr_hash) = check($root);
    return _rej('ADR_SEAL', \@trace) unless $adr_ok;
    push @trace, "adr=$adr_hash";

    my ($pok, $preason) = decide($f);
    return _rej("POLICY:$preason", \@trace) unless $pok;
    push @trace, "policy=$preason";

    my $inv = _invariant($f);
    return _rej('MATH:undefined', \@trace) unless defined $inv;
    push @trace, "invariant=$inv";

    my ($ook, $oreason, $obound) = bound($f);
    return _rej("OPT:$oreason", \@trace) unless $ook;
    push @trace, "optimize=$oreason:$obound";

    my $hd = build($f, $inv);
    push @trace, "ir=$hd->{sha256}";

    my $xml = _xml($f, $inv);
    push @trace, 'xslt=perl-bootstrap:' . sha256_hex($xml);

    my $native = _lower($root, $f);
    return _rej("NATIVE:$native->{error}", \@trace) unless $native->{ok};
    return _rej('PROOF_MISMATCH', \@trace) unless $native->{invariant} eq $inv;
    push @trace, "native=$native->{binary_sha}";

    my $cert_text = join "\n", (
        'SCM-CERT/1',
        "intent=$f->{intent}",
        "workspace=$f->{workspace}",
        "invariant=$inv",
        "native=matched",
        "policy=$preason",
        '',
    );
    my $cert_sha = sha256_hex($cert_text);
    if ($opt{cert_dir}) {
        my $path = File::Spec->catfile($opt{cert_dir}, "$f->{intent}.cert");
        open my $cf, '>', $path or return _rej('CERT_IO', \@trace);
        print {$cf} $cert_text;
        close $cf;
    }
    push @trace, "cert=$cert_sha";

    my $policy_src = _sha_file(File::Spec->catfile($root, 'perl', 'SCM', 'Policy.pm'));
    my $rec = {
        time     => $opt{time} // _now(),
        intent   => $f->{intent},
        proposal => sha256_hex($text),
        policy   => $policy_src,
        adr      => $adr_hash,
        cert     => $cert_sha,
        ir       => $hd->{sha256},
        binary   => $native->{binary_sha},
        decision => 'ALLOW',
    };
    if ($opt{seal} || $ENV{SCM_SEAL}) {
        my $path = $opt{ledger} // $ENV{SCM_LEDGER} // File::Spec->catfile($root, 'ledger', 'chain.jsonl');
        append($path, $rec);
        push @trace, 'ledger=appended';
    } else {
        push @trace, 'ledger=computed';
    }
    return {
        ok        => 1,
        code      => 0,
        line      => "ACCEPT: AUTHORIZED\n",
        trace     => \@trace,
        invariant => $inv,
        xml       => $xml,
        ir        => $hd,
        cert      => $cert_text,
    };
}

sub _invariant {
    my ($f) = @_;
    if ($f->{workspace} eq 'BRAID') {
        my @t = parse_gens($f->{target});
        return invariant(@t);
    }
    if ($f->{workspace} eq 'QUANTUM') {
        my @t = parse_gates($f->{target}, $f->{qubits} + 0);
        return tableau_key($f->{qubits} + 0, @t);
    }
    if ($f->{workspace} eq 'RECURRENCE') {
        return 'value=' . $f->{candidate_value};
    }
    return;
}

sub _xml {
    my ($f, $inv) = @_;
    return '<?xml version="1.0"?>'
      . '<scm v="1">'
      . '<intent>' . _xe($f->{intent}) . '</intent>'
      . '<workspace>' . _xe($f->{workspace}) . '</workspace>'
      . '<invariant>' . _xe($inv) . '</invariant>'
      . '</scm>';
}

sub _xe {
    my ($s) = @_;
    $s =~ s/&/&/g;
    $s =~ s/</</g;
    $s =~ s/>/>/g;
    return $s;
}

sub _lower {
    my ($root, $f) = @_;
    my $dir = tempdir('scm-native-XXXX', DIR => '/tmp', CLEANUP => 1);
    my $main = File::Spec->catfile($dir, 'main.c');
    open my $fh, '>', $main or return { ok => 0, error => 'io' };
    print {$fh} _c_main($f);
    close $fh;
    my $bin = File::Spec->catfile($dir, 'scm-native');
    my $errf = File::Spec->catfile($dir, 'gcc.err');
    my $outf = File::Spec->catfile($dir, 'run.out');
    my @gcc = (
        'gcc', '-std=c99', '-Wall', '-Werror', '-O2',
        '-I', File::Spec->catdir($root, 'compcert'),
        '-o', $bin, $main,
        File::Spec->catfile($root, 'compcert', 'scm_rt.c'),
    );
    my $rc = _exec(\@gcc, File::Spec->devnull, $errf);
    if ($rc != 0) {
        open my $e, '<', $errf;
        local $/;
        my $msg = <$e> // '';
        close $e;
        $msg =~ s/\s+/ /g;
        $msg = substr($msg, 0, 180);
        return { ok => 0, error => "compile:$msg" };
    }
    $rc = _exec([$bin], $outf, $errf);
    return { ok => 0, error => 'run' } if $rc != 0;
    open my $rf, '<', $outf or return { ok => 0, error => 'nooutput' };
    my $line = do {
        local $/ = "\n";
        my $x = <$rf> // '';
        chomp $x;
        $x;
    };
    my ($native_inv) = $line =~ /^INVARIANT (.+)\z/;
    return { ok => 0, error => 'bad_output' } unless defined $native_inv;
    open my $bf, '<:raw', $bin or return { ok => 0, error => 'binread' };
    my $bytes = do { local $/; <$bf> };
    close $bf;
    return { ok => 1, invariant => $native_inv, binary_sha => sha256_hex($bytes) };
}

sub _c_main {
    my ($f) = @_;
    my $body;
    if ($f->{workspace} eq 'BRAID') {
        my @w = parse_gens($f->{target});
        $body = "    int w[] = { " . join(', ', @w) . " };\n"
              . "    if (scm_braid_invariant(w, " . scalar(@w) . ", buf, (int)sizeof buf) != 0) return 2;\n";
    } elsif ($f->{workspace} eq 'QUANTUM') {
        my @g = parse_gates($f->{target}, $f->{qubits} + 0);
        my @rows;
        for my $i (0 .. $#g) {
            my ($op, $a, $b) = ($g[$i][0], $g[$i][1], $g[$i][2] // 0);
            my $code = $GATE_OP{$op};
            push @rows, "    g[$i].op = $code; g[$i].a = $a; g[$i].b = $b;";
        }
        $body = "    ScmGate g[" . scalar(@g) . "];\n"
              . join("\n", @rows) . "\n"
              . "    if (scm_quantum_invariant($f->{qubits}, g, " . scalar(@g) . ", buf, (int)sizeof buf) != 0) return 2;\n";
    } else {
        my @c = split / /, $f->{coeffs};
        my @a = split / /, $f->{initial};
        $body = "    int64_t coeff[] = { " . join(', ', @c) . " };\n"
              . "    int64_t init[] = { " . join(', ', @a) . " };\n"
              . "    if (scm_recurrence_invariant($f->{order}, coeff, init, $f->{target_index}, buf, (int)sizeof buf) != 0) return 2;\n";
    }
    return <<"C";
#include "scm_rt.h"
#include <stdio.h>
#include <stdint.h>
int main(void) {
    char buf[8192];
$body
    printf("INVARIANT %s\\n", buf);
    return 0;
}
C
}

sub _exec {
    my ($cmd, $outf, $errf) = @_;
    my $pid = fork();
    die 'fork' unless defined $pid;
    if ($pid == 0) {
        open STDOUT, '>', $outf or exit 127;
        open STDERR, '>', $errf or exit 127;
        exec @{$cmd} or exit 127;
    }
    waitpid($pid, 0);
    return $? >> 8;
}

sub _sha_file {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "$path: $!";
    local $/;
    my $d = <$fh>;
    close $fh;
    return sha256_hex($d);
}

sub _now {
    return $ENV{SCM_NOW} if $ENV{SCM_NOW};
    my @t = gmtime;
    return sprintf('%04d-%02d-%02dT%02d:%02d:%02dZ', $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
}

sub _root {
    my $lib = $INC{'SCM/Pipeline.pm'} // '';
    $lib =~ s{/perl/SCM/Pipeline\.pm$}{};
    return $lib;
}

sub _rej {
    my ($reason, $trace) = @_;
    return {
        ok    => 0,
        code  => 1,
        line  => "REJECT: $reason\n",
        trace => $trace,
    };
}

1;
