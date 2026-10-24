# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

package SCM::Optimize;
use strict;
use warnings;
use SCM::Braid qw(parse_gens permutation);
use SCM::Quantum qw(parse_gates tableau_key distance1);
use Exporter 'import';
our @EXPORT_OK = qw(bound);

# Necessary-condition bounds. This stage never grants authority.
# It can only reject a proposal that violates a bound the math stage
# should already have implied. A disagreement fails closed.

sub bound {
    my ($f) = @_;
    my $ws = $f->{workspace};
    if ($ws eq 'BRAID') {
        my @t = parse_gens($f->{target});
        my @c = parse_gens($f->{candidate});
        my $tp = join ',', permutation(@t);
        my $cp = join ',', permutation(@c);
        return (0, 'permutation_mismatch', 0) unless $tp eq $cp;
        my $shortest = _perm_shortest($tp);
        return (0, 'below_permutation_bound', $shortest) if @c < $shortest;
        return (1, 'permutation_bound', $shortest);
    }
    if ($ws eq 'QUANTUM') {
        my $nq = $f->{qubits} + 0;
        my @c = parse_gates($f->{candidate}, $nq);
        if ($nq == 1) {
            my @t = parse_gates($f->{target}, 1);
            my $d = distance1(@t);
            return (0, 'distance_unknown', -1) if $d < 0;
            return (0, 'below_clifford_distance', $d) if @c < $d;
            return (1, 'clifford_distance', $d);
        }
        my @t = parse_gates($f->{target}, $nq);
        my $id = tableau_key($nq);
        my $key = tableau_key($nq, @t);
        my $floor = ($key eq $id) ? 0 : 1;
        return (0, 'below_gate_floor', $floor) if @c < $floor;
        return (1, 'gate_floor', $floor);
    }
    if ($ws eq 'RECURRENCE') {
        return (1, 'exact_recomputation', $f->{order} + 0);
    }
    return (0, 'unknown_workspace', 0);
}

sub _perm_shortest {
    my ($target) = @_;
    my @q = ([0, 1, 2, 0]);
    my %seen = ('0,1,2' => 0);
    while (@q) {
        my ($a, $b, $c, $d) = @{ shift @q };
        my $key = "$a,$b,$c";
        return $d if $key eq $target;
        next if $d >= 6;
        for my $i (0, 1) {
            my @p = ($a, $b, $c);
            @p[$i, $i + 1] = @p[$i + 1, $i];
            my $k = join ',', @p;
            next if exists $seen{$k};
            $seen{$k} = $d + 1;
            push @q, [ @p, $d + 1 ];
        }
    }
    return 99;
}

1;
