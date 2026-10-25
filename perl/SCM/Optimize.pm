# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

package SCM::Optimize;
use strict;
use warnings;
use SCM::Braid qw(parse_gens parse_gens_strict permutation equivalent);
use SCM::Quantum qw(parse_gates tableau_key distance1);
use Exporter 'import';
our @EXPORT_OK = qw(bound optimize_exact);

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

# Exact optimizer for BRAID words (the bound stage above is necessary
# conditions only; this is the stage that actually selects a minimum).
# Enumerates all signed-generator words up to max_length, including the
# empty word, checks Artin equivalence against the target, and selects
# the minimum by (weighted cost, word length, lexical order). Only a
# completed enumeration reports OPTIMAL_WITHIN_BOUNDS; a budget-exhausted
# search reports INCOMPLETE_SEARCH with the best valid candidate found.
# A partial search is never labeled globally optimal. Costs are
# caller-supplied ({s1, s2, s1_inv, s2_inv}); missing entries default
# to 1. Returns (status, word_string, cost, candidates_examined).
sub optimize_exact {
    my ($target, $costs, $max_length, $max_candidates) = @_;
    my $t = ref($target) eq 'ARRAY' ? $target : parse_gens_strict($target);
    return ('INVALID_TARGET', '', 0, 0) unless defined $t;
    return ('INVALID_BOUND', '', 0, 0)
        unless defined $max_length && $max_length =~ /^\d+$/;
    $max_candidates = 1_000_000 unless defined $max_candidates;
    my @gens = (1, -1, 2, -2);
    my %cost = (s1 => 1, s2 => 1, s1_inv => 1, s2_inv => 1, %{$costs // {}});
    my %name = (1 => 's1', -1 => 's1_inv', 2 => 's2', -2 => 's2_inv');
    my $best;
    my $examined = 0;
    my $complete = 1;
    for my $len (0 .. $max_length) {
        my @words = ([]);
        for my $pos (1 .. $len) {
            my @next;
            for my $w (@words) {
                for my $g (@gens) {
                    push @next, [ @$w, $g ];
                }
            }
            @words = @next;
        }
        for my $word (@words) {
            $examined++;
            if ($examined > $max_candidates) {
                $complete = 0;
                last;
            }
            next unless equivalent($t, $word);
            my $c = 0;
            $c += $cost{ $name{$_} } for @$word;
            my $ws = join ',', map { $name{$_} } @$word;
            my $cand = { word => $ws, cost => $c, length => scalar @$word };
            if (!defined $best
                || $cand->{cost} < $best->{cost}
                || ($cand->{cost} == $best->{cost} && $cand->{length} < $best->{length})
                || ($cand->{cost} == $best->{cost} && $cand->{length} == $best->{length} && $cand->{word} lt $best->{word})) {
                $best = $cand;
            }
        }
        last unless $complete;
    }
    return ('NO_CANDIDATE', '', 0, $examined) unless defined $best;
    return ($complete ? 'OPTIMAL_WITHIN_BOUNDS' : 'INCOMPLETE_SEARCH',
        $best->{word}, $best->{cost}, $examined);
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
