# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

package SCM::Policy;
use strict;
use warnings;
use SCM::Braid qw(parse_gens);
use SCM::Quantum qw(parse_gates);
use SCM::Recurrence qw(evaluate);
use Exporter 'import';
our @EXPORT_OK = qw(decide decide_braid_words);

# Deny by default. A missing clause is a denial. The model cannot extend
# this table: unrecognized workspaces and missing obligations fall through
# to DENY.

sub _has {
    my ($set, $id) = @_;
    return exists $set->{$id};
}

sub decide {
    my ($f) = @_;
    my $ws = $f->{workspace} // '';
    if ($ws eq 'BRAID') {
        return _braid($f);
    } elsif ($ws eq 'QUANTUM') {
        return _quantum($f);
    } elsif ($ws eq 'RECURRENCE') {
        return _recurrence($f);
    }
    return (0, 'unknown_workspace');
}

sub decide_braid_words {
    my ($ws, $target, $candidate) = @_;
    return (0, 'unknown_workspace') unless defined $ws && $ws eq 'BRAID';
    my @t = parse_gens($target);
    my @c = parse_gens($candidate);
    return (0, 'invalid_word') unless @t && @c;
    return (0, 'no_trusted_equivalence') unless SCM::Braid::equivalent(\@t, \@c);
    return (1, 'artin_equivalence');
}

sub _obs {
    my ($f) = @_;
    my %o = map { $_ => 1 } split / /, ($f->{proof_obligations} // '');
    return \%o;
}

sub _count {
    my ($s) = @_;
    return scalar split / /, ($s // '');
}

sub _braid {
    my ($f) = @_;
    my @t = parse_gens($f->{target});
    my @c = parse_gens($f->{candidate});
    return (0, 'invalid_word') unless @t && @c;
    return (0, 'cost_contract') unless $f->{cost} == @c;
    my $same = ($f->{target} eq $f->{candidate}) ? 1 : 0;
    my $xf = $f->{transformations} + 0;
    if ($same) {
        return (0, 'transformation_contract') unless $xf == 0;
    } else {
        return (0, 'transformation_contract') unless $xf >= 1;
    }
    my $o = _obs($f);
    return (0, 'missing_obligation') unless _has($o, 'RP-001') && _has($o, 'RP-002');
    return (0, 'missing_obligation') if !$same && !_has($o, 'RP-003');
    return (0, 'no_trusted_equivalence') unless SCM::Braid::equivalent(\@t, \@c);
    return (1, 'artin_equivalence');
}

sub _quantum {
    my ($f) = @_;
    my $nq = $f->{qubits} + 0;
    my @t = parse_gates($f->{target}, $nq);
    my @c = parse_gates($f->{candidate}, $nq);
    return (0, 'invalid_circuit') unless @t && @c;
    return (0, 'cost_contract') unless $f->{cost} == @c;
    my $same = ($f->{target} eq $f->{candidate}) ? 1 : 0;
    my $xf = $f->{transformations} + 0;
    if ($same) {
        return (0, 'transformation_contract') unless $xf == 0;
    } else {
        return (0, 'transformation_contract') unless $xf >= 1;
    }
    my $o = _obs($f);
    return (0, 'missing_obligation') unless _has($o, 'CQ-001') && _has($o, 'CQ-002');
    return (0, 'no_trusted_equivalence') unless SCM::Quantum::equivalent($nq, \@t, \@c);
    return (1, 'clifford_equivalence');
}

sub _recurrence {
    my ($f) = @_;
    my $k = $f->{order} + 0;
    return (0, 'cost_contract') unless $f->{cost} == $k;
    my @c = split / /, $f->{coeffs};
    my @a = split / /, $f->{initial};
    my $got = evaluate($k, \@c, \@a, $f->{target_index} + 0);
    return (0, 'overflow_or_undefined') unless defined $got;
    return (0, 'target_mismatch') unless $got == $f->{target_value};
    my $same = ($got == $f->{candidate_value}) ? 1 : 0;
    my $xf = $f->{transformations} + 0;
    if ($same) {
        return (0, 'transformation_contract') unless $xf == 0;
    } else {
        return (0, 'transformation_contract') unless $xf >= 1;
    }
    my $o = _obs($f);
    return (0, 'missing_obligation') unless _has($o, 'RR-001') && _has($o, 'RR-002');
    return (0, 'no_trusted_equivalence') unless $same;
    return (1, 'recurrence_recomputation');
}

1;
