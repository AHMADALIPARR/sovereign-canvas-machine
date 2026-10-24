# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

package SCM::Braid;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT_OK = qw(parse_gens invariant permutation equivalent);

# Artin representation of B3 on the free group F3.
# Faithful: two words are equal in B3 iff the freely reduced images agree.
# Generator sign: +1 s1, -1 s1_inv, +2 s2, -2 s2_inv.
# Free letters: +1,+2,+3 and their inverses.

my %ACT = (
    1  => { 1 => [1, 2, -1], 2 => [1],       3 => [3] },
    -1 => { 1 => [2],        2 => [-2, 1, 2], 3 => [3] },
     2 => { 1 => [1],        2 => [2, 3, -2], 3 => [2] },
    -2 => { 1 => [1],        2 => [3],         3 => [-3, 2, 3] },
);

sub parse_gens {
    my ($s) = @_;
    my @o;
    for my $tok (split / /, $s // '') {
        if    ($tok eq 's1')     { push @o, 1 }
        elsif ($tok eq 's1_inv') { push @o, -1 }
        elsif ($tok eq 's2')     { push @o, 2 }
        elsif ($tok eq 's2_inv') { push @o, -2 }
        else                     { return }
    }
    return @o;
}

sub freduce {
    my @s;
    for my $g (@_) {
        if (@s && $s[-1] == -$g) { pop @s }
        else                     { push @s, $g }
    }
    return @s;
}

sub apply_word {
    my @img = ([1], [2], [3]);
    for my $g (@_) {
        my $map = $ACT{$g} or return;
        my @next;
        for my $strand (0 .. 2) {
            my @buf;
            for my $L (@{ $img[$strand] }) {
                my $piece = $map->{ abs($L) };
                if ($L > 0) { push @buf, @$piece }
                else        { push @buf, map { -$_ } reverse @$piece }
            }
            push @next, [ freduce(@buf) ];
        }
        @img = @next;
    }
    return @img;
}

sub invariant {
    my @img = apply_word(@_);
    return join ';', map { join(',', @$_) } @img;
}

sub equivalent {
    my ($a, $b) = @_;
    my @wa = ref($a) eq 'ARRAY' ? @$a : parse_gens($a);
    my @wb = ref($b) eq 'ARRAY' ? @$b : parse_gens($b);
    return 0 unless @wa && @wb;
    return invariant(@wa) eq invariant(@wb);
}

sub permutation {
    my @p = (0, 1, 2);
    for my $g (@_) {
        my $i = (abs($g) == 1) ? 0 : 1;
        @p[ $i, $i + 1 ] = @p[ $i + 1, $i ];
    }
    return @p;
}

1;
