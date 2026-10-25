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
our @EXPORT_OK = qw(build canon_json canon_xml leaf_hash section_hash
    merkle_root verify_xml_hashes);

# Braided causal hypergraph of the candidate, plus the semantic invariant.
# Crossings are hyperedges on two strands. Continuity edges follow each
# strand through the diagram. The invariant is the authoritative digest;
# the diagram is the syntactic witness and is not itself an equivalence.
#
# ANYON MODEL (BRAID workspace only). Each strand is an anyon worldline
# in 2+1 dimensions; each crossing is a braiding event between the two
# anyons on the adjacent positions. Convention, the standard one: a
# positive generator (s1, s2) braids the left strand OVER the right
# strand; a negative generator (s1_inv, s2_inv) braids the right strand
# OVER the left. A strand's trajectory is the ordered list of crossings
# it participates in, with its role (over/under) and its partner at each.
# Equivalent words share an invariant and not necessarily a diagram, and
# not necessarily anyon trajectories: the diagram is a witness, and the
# invariant is what the pipeline trusts.
#
# MERKLE DAG. Every element (node, hyperedge, continuity edge, anyon)
# carries a leaf hash; every section carries the hash of its children's
# leaf hashes in order; the root commits to intent, workspace,
# invariant, and all four section hashes. Leaf preimage: the record's
# keys sorted, "k=v" pairs joined by "," (array values comma-joined).
# Section hash: sha256 of the concatenation of child leaf hashes in
# order; an empty section hashes sha256(''). Root preimage: intent,
# workspace, invariant, nodes hash, hyperedges hash, continuity hash,
# anyons hash, joined by "\n" (which no field value can contain: the
# decoders reject it). The XML tree carries every hash, so the tree
# alone is verifiable: recompute each leaf from its non-hash
# attributes, fold up, and compare with the root.

sub _leaf_preimage {
    my ($rec) = @_;
    my @pairs;
    for my $k (sort keys %$rec) {
        my $v = $rec->{$k};
        if (ref $v eq 'ARRAY') {
            $v = join ',', @$v;
        } elsif (ref $v) {
            die "leaf_hash: unsupported ref for $k";
        }
        push @pairs, "$k=$v";
    }
    return join ',', @pairs;
}

sub leaf_hash {
    my ($rec) = @_;
    return sha256_hex(_leaf_preimage($rec));
}

sub section_hash {
    my ($rows) = @_;
    return sha256_hex(join '', map { leaf_hash($_) } @$rows);
}

sub merkle_root {
    my ($ir) = @_;
    return sha256_hex(join "\n",
        $ir->{intent}, $ir->{workspace}, $ir->{invariant},
        section_hash($ir->{nodes} // []),
        section_hash($ir->{hyperedges} // []),
        section_hash($ir->{continuity} // []),
        section_hash($ir->{anyons} // []));
}

sub build {
    my ($f, $invariant) = @_;
    my $ws = $f->{workspace};
    my @nodes;
    my @hyper;
    my @continuity;
    my @anyons;
    if ($ws eq 'BRAID') {
        my @g = parse_gens($f->{candidate});
        my @pos = (0, 1, 2);
        my @last = (-1, -1, -1);
        my @traj = ([], [], []);
        for my $i (0 .. $#g) {
            my $abs = abs($g[$i]);
            my $p = $abs == 1 ? 0 : 1;
            my $sign = $g[$i] > 0 ? 1 : -1;
            my ($s0, $s1) = ($pos[$p], $pos[$p + 1]);
            push @nodes, { id => $i, sign => $sign, a => $s0, b => $s1 };
            push @hyper, { id => "x$i", strands => [ $s0, $s1 ], node => $i };
            my ($over, $under) = $sign > 0 ? ($s0, $s1) : ($s1, $s0);
            push @{ $traj[$over] },  { crossing => $i, role => 'over',  partner => $under };
            push @{ $traj[$under] }, { crossing => $i, role => 'under', partner => $over };
            for my $s ($s0, $s1) {
                if ($last[$s] >= 0) {
                    push @continuity, { strand => $s, from => $last[$s], to => $i };
                }
                $last[$s] = $i;
            }
            @pos[$p, $p + 1] = @pos[$p + 1, $p];
        }
        for my $s (0, 1, 2) {
            push @anyons, {
                id        => $s,
                crossings => [ map { $_->{crossing} } @{ $traj[$s] } ],
                roles     => [ map { $_->{role} } @{ $traj[$s] } ],
                partners  => [ map { $_->{partner} } @{ $traj[$s] } ],
            };
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
        anyons     => \@anyons,
    };
    $ir->{merkle} = {
        root       => merkle_root($ir),
        nodes      => section_hash(\@nodes),
        hyperedges => section_hash(\@hyper),
        continuity => section_hash(\@continuity),
        anyons     => section_hash(\@anyons),
    };
    my $json = canon_json($ir);
    return {
        ir      => $ir,
        json    => $json,
        sha256  => sha256_hex($json),
        merkle  => $ir->{merkle}{root},
        xml     => canon_xml($ir),
    };
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

# Canonical XML tree of the hypergraph. Root is <scm v="1"> carrying
# intent, workspace, and invariant, so the existing stylesheet
# (xslt/canonicalize.xsl, match /scm) projects this tree down to the
# semantic certificate without modification. Element order is
# construction order; attribute order is id first, then remaining keys
# sorted, then the leaf hash last (the hash is derived, never part of
# its own preimage). The same diagram always serializes to the same
# bytes, and the bytes alone verify: recompute each leaf from its
# non-hash attributes, fold sections, compare with the root.
sub _xml_escape {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    $s =~ s/'/&apos;/g;
    return $s;
}

sub _xml_attrs {
    my ($rec) = @_;
    my @keys = ('id', sort grep { $_ ne 'id' } keys %$rec);
    my @out;
    for my $k (@keys) {
        next unless exists $rec->{$k};
        my $v = $rec->{$k};
        if (ref $v eq 'ARRAY') {
            $v = join ',', @$v;
        } elsif (ref $v) {
            die "canon_xml: unsupported attribute ref for $k";
        }
        push @out, qq{$k="} . _xml_escape("$v") . q{"};
    }
    return @out ? ' ' . join(' ', @out) : '';
}

sub _xml_section {
    my ($tag, $elem, $rows, $hash) = @_;
    my $open = "    <$tag hash=\"$hash\"";
    return "$open/>\n" unless @$rows;
    my $s = "$open>\n";
    for my $r (@$rows) {
        $s .= "      <$elem" . _xml_attrs($r)
            . qq{ hash="} . leaf_hash($r) . qq{"/>\n};
    }
    $s .= "    </$tag>\n";
    return $s;
}

sub canon_xml {
    my ($ir) = @_;
    my $m = $ir->{merkle} // {
        root       => merkle_root($ir),
        nodes      => section_hash($ir->{nodes} // []),
        hyperedges => section_hash($ir->{hyperedges} // []),
        continuity => section_hash($ir->{continuity} // []),
        anyons     => section_hash($ir->{anyons} // []),
    };
    my $x = qq{<?xml version="1.0"?>\n<scm v="} . _xml_escape($ir->{v}) . qq{">\n};
    $x .= '  <intent>' . _xml_escape($ir->{intent}) . "</intent>\n";
    $x .= '  <workspace>' . _xml_escape($ir->{workspace}) . "</workspace>\n";
    $x .= '  <invariant>' . _xml_escape($ir->{invariant}) . "</invariant>\n";
    $x .= '  <diagram>' . "\n";
    $x .= _xml_section('nodes', 'node', $ir->{nodes} // [], $m->{nodes});
    $x .= _xml_section('hyperedges', 'hyperedge', $ir->{hyperedges} // [], $m->{hyperedges});
    $x .= _xml_section('continuity', 'edge', $ir->{continuity} // [], $m->{continuity});
    $x .= _xml_section('anyons', 'anyon', $ir->{anyons} // [], $m->{anyons});
    $x .= "  </diagram>\n";
    $x .= '  <merkle root="' . $m->{root} . '" nodes="' . $m->{nodes}
        . '" hyperedges="' . $m->{hyperedges}
        . '" continuity="' . $m->{continuity}
        . '" anyons="' . $m->{anyons} . "\"/>\n";
    $x .= "</scm>\n";
    return $x;
}

# Verify a canonical XML tree produced by canon_xml, from the bytes
# alone: parse elements with a small purpose-built reader (no XML
# library is assumed), recompute every leaf hash from its non-hash
# attributes, fold each section, and compare with the <merkle> root.
# Returns (1, 'ok') or (0, $reason). This is the check the suite runs:
# a tampered attribute must break the root.
sub verify_xml_hashes {
    my ($xml) = @_;
    return (0, 'no_merkle') unless $xml =~ /<merkle root="([0-9a-f]{64})"/;
    my $root = $1;
    my %section;
    for my $tag (qw(nodes hyperedges continuity anyons)) {
        return (0, "no_section_$tag") unless $xml =~ /<$tag hash="([0-9a-f]{64})"/;
        $section{$tag} = $1;
        my ($body) = $xml =~ /<$tag hash="[0-9a-f]{64}"(?:\/>|>(.*?)<\/$tag>)/s;
        my @leaf;
        if (defined $body) {
            while ($body =~ /<\w+([^>]*?)\/>/g) {
                my $attrs = $1;
                return (0, "leaf_without_hash_$tag") unless $attrs =~ / hash="([0-9a-f]{64})"/;
                my $want = $1;
                my %rec;
                while ($attrs =~ /(\w[\w-]*)="([^"]*)"/g) {
                    next if $1 eq 'hash';
                    my ($k, $v) = ($1, $2);
                    $v =~ s/&apos;/'/g;
                    $v =~ s/&quot;/"/g;
                    $v =~ s/&gt;/>/g;
                    $v =~ s/&lt;/</g;
                    $v =~ s/&amp;/&/g;
                    $rec{$k} = $v;
                }
                # Array-valued attributes (strands, crossings, roles,
                # partners) round-trip as comma-joined strings; split
                # them back so the preimage matches the writer's.
                for my $k (qw(strands crossings roles partners)) {
                    if (exists $rec{$k}) {
                        $rec{$k} = $rec{$k} eq '' ? [] : [ split /,/, $rec{$k} ];
                    }
                }
                my $got = leaf_hash(\%rec);
                return (0, "leaf_mismatch_$tag") unless $got eq $want;
                push @leaf, $want;
            }
        }
        my $fold = sha256_hex(join '', @leaf);
        return (0, "section_mismatch_$tag") unless $fold eq $section{$tag};
    }
    my ($intent) = $xml =~ /<intent>(.*?)<\/intent>/s;
    my ($ws)     = $xml =~ /<workspace>(.*?)<\/workspace>/s;
    my ($inv)    = $xml =~ /<invariant>(.*?)<\/invariant>/s;
    return (0, 'no_header')
        unless defined $intent && defined $ws && defined $inv;
    my $recomputed = sha256_hex(join "\n", $intent, $ws, $inv,
        $section{nodes}, $section{hyperedges},
        $section{continuity}, $section{anyons});
    return (0, 'root_mismatch') unless $recomputed eq $root;
    return (1, 'ok');
}

1;
