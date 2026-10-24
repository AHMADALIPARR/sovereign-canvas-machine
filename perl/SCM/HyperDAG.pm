# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

package SCM::HyperDAG;
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use SCM::Braid qw(parse_gens);
use Exporter 'import';
our @EXPORT_OK = qw(build canon_json);

# Braided causal hypergraph of the candidate, plus the semantic invariant.
# Crossings are hyperedges on two strands. Continuity edges follow each
# strand through the diagram. The invariant is the authoritative digest;
# the diagram is the syntactic witness and is not itself an equivalence.

sub build {
    my ($f, $invariant) = @_;
    my $ws = $f->{workspace};
    my @nodes;
    my @hyper;
    my @continuity;
    if ($ws eq 'BRAID') {
        my @g = parse_gens($f->{candidate});
        my @pos = (0, 1, 2);
        my @last = (-1, -1, -1);
        for my $i (0 .. $#g) {
            my $abs = abs($g[$i]);
            my $p = $abs == 1 ? 0 : 1;
            my $sign = $g[$i] > 0 ? 1 : -1;
            my ($s0, $s1) = ($pos[$p], $pos[$p + 1]);
            push @nodes, { id => $i, sign => $sign, a => $s0, b => $s1 };
            push @hyper, { id => "x$i", strands => [ $s0, $s1 ], node => $i };
            for my $s ($s0, $s1) {
                if ($last[$s] >= 0) {
                    push @continuity, { strand => $s, from => $last[$s], to => $i };
                }
                $last[$s] = $i;
            }
            @pos[$p, $p + 1] = @pos[$p + 1, $p];
        }
    } elsif ($ws eq 'QUANTUM') {
        my $i = 0;
        for my $tok (split / /, $f->{candidate}) {
            push @nodes, { id => $i, gate => $tok };
            push @continuity, { from => $i - 1, to => $i } if $i > 0;
            $i++;
        }
    } else {
        push @nodes, {
            id    => 0,
            order => $f->{order},
            index => $f->{target_index},
            value => $f->{candidate_value},
        };
    }
    my $ir = {
        v          => 1,
        workspace  => $ws,
        intent     => $f->{intent},
        invariant  => $invariant,
        nodes      => \@nodes,
        hyperedges => \@hyper,
        continuity => \@continuity,
    };
    my $json = canon_json($ir);
    return { ir => $ir, json => $json, sha256 => sha256_hex($json) };
}

sub canon_json {
    my ($v) = @_;
    my $r = ref $v;
    if (!$r) {
        if (!defined $v) { return 'null' }
        if ($v =~ /^-?\d+$/ && $v !~ /^-?0\d/) { return $v + 0 }
        $v =~ s/\\/\\\\/g;
        $v =~ s/"/\\"/g;
        return qq{"$v"};
    }
    if ($r eq 'ARRAY') {
        return '[' . join(',', map { canon_json($_) } @$v) . ']';
    }
    if ($r eq 'HASH') {
        my @k = sort keys %$v;
        return '{' . join(',', map { canon_json($_) . ':' . canon_json($v->{$_}) } @k) . '}';
    }
    die "bad json ref $r";
}

1;
