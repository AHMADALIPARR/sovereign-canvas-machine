# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

package SCM::Recurrence;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT_OK = qw(evaluate);

# a_n = c0*a_{n-1} + c1*a_{n-2} + ... + c_{k-1}*a_{n-k}
# Values outside [-1e9, 1e9] are rejected so the C lowering stays in int64
# without silent wrap.

use constant BOUND => 1000000000;

sub evaluate {
    my ($order, $coeffs, $initial, $index) = @_;
    return if $order < 1 || @$coeffs != $order || @$initial != $order;
    return if $index < 0 || $index > 30;
    my @a = @$initial;
    for my $v (@a) {
        return if $v < -BOUND || $v > BOUND;
    }
    if ($index < $order) {
        return $a[$index];
    }
    for my $n ($order .. $index) {
        my $s = 0;
        for my $j (0 .. $order - 1) {
            $s += $coeffs->[$j] * $a[ $n - 1 - $j ];
            return if $s < -BOUND || $s > BOUND;
        }
        push @a, $s;
    }
    return $a[$index];
}

1;
