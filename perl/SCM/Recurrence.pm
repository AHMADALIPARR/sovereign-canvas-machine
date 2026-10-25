# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

package SCM::Recurrence;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT_OK = qw(evaluate sequence);

# a_n = c0*a_{n-1} + c1*a_{n-2} + ... + c_{k-1}*a_{n-k}
# Values outside [-1e9, 1e9] are rejected so the C lowering stays in int64
# without silent wrap.

use constant BOUND => 1000000000;

# Shared engine: validate parameters, then extend the initial values out
# to $index under the bound. Returns the full sequence, or undef on any
# violation (bad shape, bad index, any value outside ±BOUND).
sub _run {
    my ($order, $coeffs, $initial, $index) = @_;
    return if $order < 1 || @$coeffs != $order || @$initial != $order;
    return if $index < 0 || $index > 30;
    my @a = @$initial;
    for my $v (@a) {
        return if $v < -BOUND || $v > BOUND;
    }
    for my $n ($order .. $index) {
        my $s = 0;
        for my $j (0 .. $order - 1) {
            $s += $coeffs->[$j] * $a[ $n - 1 - $j ];
            return if $s < -BOUND || $s > BOUND;
        }
        push @a, $s;
    }
    return \@a;
}

sub evaluate {
    my ($order, $coeffs, $initial, $index) = @_;
    my $seq = _run($order, $coeffs, $initial, $index);
    return unless defined $seq;
    return $seq->[$index];
}

# Full computed sequence a_0..a_index under the same contract as
# evaluate(). Returns an array reference, or undef on any violation.
# Useful for tests and diagnostics; evaluate() remains the single-value
# entry point the policy stage calls.
sub sequence {
    my ($order, $coeffs, $initial, $index) = @_;
    return _run($order, $coeffs, $initial, $index);
}

1;
