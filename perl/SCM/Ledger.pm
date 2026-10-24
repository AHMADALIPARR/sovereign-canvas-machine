# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

package SCM::Ledger;
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use Exporter 'import';
our @EXPORT_OK = qw(append verify genesis_prev);

use constant GENESIS => '0' x 64;

sub genesis_prev { return GENESIS }

sub _line {
    my ($r) = @_;
    return join ' ', map { "$_=$r->{$_}" } qw(
        index prev time intent proposal policy adr cert ir binary decision
    );
}

sub append {
    my ($path, $rec) = @_;
    my $prev = GENESIS;
    my $index = 0;
    if (-f $path) {
        open my $in, '<', $path or die "ledger read: $!";
        local $/ = "\n";
        my $last;
        while (my $l = <$in>) {
            chomp $l;
            next if $l eq '';
            $last = $l;
            $index++;
        }
        close $in;
        if (defined $last) {
            $prev = sha256_hex($last);
        }
    }
    my %r = (
        index    => $index,
        prev     => $prev,
        time     => $rec->{time},
        intent   => $rec->{intent},
        proposal => $rec->{proposal},
        policy   => $rec->{policy},
        adr      => $rec->{adr},
        cert     => $rec->{cert},
        ir       => $rec->{ir},
        binary   => $rec->{binary},
        decision => $rec->{decision},
    );
    for my $v (values %r) {
        die 'ledger field rejected' if !defined $v || $v =~ /[\s\n]/;
    }
    my $line = _line(\%r);
    open my $out, '>>', $path or die "ledger append: $!";
    print {$out} $line, "\n";
    close $out;
    return { line => $line, hash => sha256_hex($line), index => $index };
}

sub verify {
    my ($path) = @_;
    return (1, 'empty') unless -f $path;
    open my $in, '<', $path or return (0, 'unreadable');
    local $/ = "\n";
    my $prev = GENESIS;
    my $i = 0;
    while (my $l = <$in>) {
        chomp $l;
        next if $l eq '';
        my %f = map { split /=/, $_, 2 } split / /, $l;
        return (0, "prev_mismatch_$i") unless ($f{prev} // '') eq $prev;
        return (0, "index_mismatch_$i") unless ($f{index} // '') eq "$i";
        $prev = sha256_hex($l);
        $i++;
    }
    close $in;
    return (1, "records=$i");
}

1;
