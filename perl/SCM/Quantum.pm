# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

package SCM::Quantum;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT_OK = qw(parse_gates tableau_key equivalent distance1);

# Clifford tableau. A Pauli on n<=4 qubits is i^p * tensor_q (X^{x_q} Z^{z_q}),
# with X before Z on each qubit. Conjugation by each allowed gate is tracked
# on the images of X_q and Z_q, which determines the Clifford up to global phase.

sub mul {
    my ($a, $b) = @_;
    my $n  = $a->{n};
    my $ph = ($a->{p} + $b->{p}) % 4;
    for my $i (0 .. $n - 1) {
        my $z1 = ($a->{z} >> $i) & 1;
        my $x2 = ($b->{x} >> $i) & 1;
        $ph = ($ph + 2 * $z1 * $x2) % 4;
    }
    return { n => $n, x => $a->{x} ^ $b->{x}, z => $a->{z} ^ $b->{z}, p => $ph };
}

sub xop { my ($n, $q) = @_; return { n => $n, x => 1 << $q, z => 0, p => 0 } }
sub zop { my ($n, $q) = @_; return { n => $n, x => 0, z => 1 << $q, p => 0 } }

sub parse_gates {
    my ($s, $nq) = @_;
    my @g;
    for my $tok (split / /, $s // '') {
        if ($tok =~ /^(H|X|Y|Z|S|SDG):(\d+)$/) {
            return if $2 >= $nq;
            push @g, [ $1, $2 + 0 ];
        } elsif ($tok =~ /^(CNOT|CZ):(\d+):(\d+)$/) {
            return if $2 == $3 || $2 >= $nq || $3 >= $nq;
            push @g, [ $1, $2 + 0, $3 + 0 ];
        } else {
            return;
        }
    }
    return @g;
}

sub gate_images {
    my ($n, $gate) = @_;
    my @X = map { xop($n, $_) } 0 .. $n - 1;
    my @Z = map { zop($n, $_) } 0 .. $n - 1;
    my ($op, @a) = @$gate;
    if ($op eq 'H') {
        my $q = $a[0];
        ($X[$q], $Z[$q]) = ($Z[$q], $X[$q]);
    } elsif ($op eq 'S') {
        my $q = $a[0];
        my $y = mul(xop($n, $q), zop($n, $q));
        $y->{p} = ($y->{p} + 1) % 4;
        $X[$q] = $y;
    } elsif ($op eq 'SDG') {
        my $q = $a[0];
        my $y = mul(xop($n, $q), zop($n, $q));
        $y->{p} = ($y->{p} + 3) % 4;
        $X[$q] = $y;
    } elsif ($op eq 'X') {
        $Z[ $a[0] ]{p} = ($Z[ $a[0] ]{p} + 2) % 4;
    } elsif ($op eq 'Z') {
        $X[ $a[0] ]{p} = ($X[ $a[0] ]{p} + 2) % 4;
    } elsif ($op eq 'Y') {
        $X[ $a[0] ]{p} = ($X[ $a[0] ]{p} + 2) % 4;
        $Z[ $a[0] ]{p} = ($Z[ $a[0] ]{p} + 2) % 4;
    } elsif ($op eq 'CNOT') {
        my ($c, $t) = @a;
        $X[$c] = mul(xop($n, $c), xop($n, $t));
        $Z[$t] = mul(zop($n, $c), zop($n, $t));
    } elsif ($op eq 'CZ') {
        my ($c, $t) = @a;
        $X[$c] = mul(xop($n, $c), zop($n, $t));
        $X[$t] = mul(zop($n, $c), xop($n, $t));
    } else {
        die "bad gate $op";
    }
    return (\@X, \@Z);
}

sub conjugate {
    my ($p, $Xs, $Zs) = @_;
    my $n   = $p->{n};
    my $acc = { n => $n, x => 0, z => 0, p => $p->{p} };
    for my $i (0 .. $n - 1) {
        $acc = mul($acc, $Xs->[$i]) if ($p->{x} >> $i) & 1;
        $acc = mul($acc, $Zs->[$i]) if ($p->{z} >> $i) & 1;
    }
    return $acc;
}

sub _fmt {
    my ($p) = @_;
    return "$p->{x},$p->{z},$p->{p}";
}

sub tableau_key {
    my ($n, @gates) = @_;
    my @curX = map { xop($n, $_) } 0 .. $n - 1;
    my @curZ = map { zop($n, $_) } 0 .. $n - 1;
    for my $g (@gates) {
        my ($Xs, $Zs) = gate_images($n, $g);
        @curX = map { conjugate($_, $Xs, $Zs) } @curX;
        @curZ = map { conjugate($_, $Xs, $Zs) } @curZ;
    }
    my @parts;
    for my $i (0 .. $n - 1) {
        push @parts, "X$i:" . _fmt($curX[$i]), "Z$i:" . _fmt($curZ[$i]);
    }
    return join '|', @parts;
}

sub equivalent {
    my ($n, $a, $b) = @_;
    my @ga = ref($a) eq 'ARRAY' ? @$a : parse_gates($a, $n);
    my @gb = ref($b) eq 'ARRAY' ? @$b : parse_gates($b, $n);
    return 0 unless @ga && @gb;
    return tableau_key($n, @ga) eq tableau_key($n, @gb);
}

# Exact distance on one qubit over the allowed gate set. The group is finite
# (24 Cliffords up to global phase, a few more with our phase tracking).
sub distance1 {
    my (@target_gates) = @_;
    my $target = tableau_key(1, @target_gates);
    my $origin = tableau_key(1);
    return 0 if $target eq $origin;
    my @gen = map { [ $_, 0 ] } qw(H X Y Z S SDG);
    my @q = ( [] );
    my %seen = ( $origin => 1 );
    my $guard = 0;
    while (@q) {
        my $seq = shift @q;
        my $d   = scalar @$seq;
        return $d if $d > 0 && tableau_key(1, @$seq) eq $target;
        next if $d >= 8;
        for my $g (@gen) {
            my @nseq = ( @$seq, $g );
            my $k = tableau_key(1, @nseq);
            next if $seen{$k}++;
            push @q, \@nseq;
        }
        die 'distance blowup' if ++$guard > 20000;
    }
    return -1;
}

1;
