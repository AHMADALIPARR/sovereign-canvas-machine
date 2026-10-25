#!/usr/bin/perl
# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

# verify_ampl.pl — Check the AMPL contract (ampl/braid_perm.mod) against
# the executed implementation, without an AMPL binary. AMPL is not
# available in this environment and the supervisor does not call it; the
# executed bound is the BFS in perl/SCM/Optimize.pm. What this script
# proves is that the model file agrees with the implementation on every
# entry: every image[] row recomputed from SCM::Braid::permutation,
# every len[] entry recomputed from the word, the word set checked
# complete for positive words of length <= 3, and the model's target
# optimum (shortest word reaching the target permutation) recomputed by
# an independent S3 breadth-first search written here, not imported
# from Optimize. Exit 0 on agreement, 1 on the first mismatch.
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use SCM::Braid qw(permutation);

my $ROOT = $FindBin::Bin;
$ROOT =~ s{/perl\z}{};
my $MOD = "$ROOT/ampl/braid_perm.mod";

open my $fh, '<', $MOD or die "Cannot read $MOD: $!";
local $/;
my $text = <$fh>;
close $fh;

sub fail {
    my ($msg) = @_;
    print "AMPL_MISMATCH: $msg\n";
    exit 1;
}

my ($len_sec) = $text =~ /param len :=(.*?);/s;
fail('len section not found') unless defined $len_sec;
my %len;
while ($len_sec =~ /(\S+)\s+(\d+)/g) {
    $len{$1} = $2 + 0;
}

my ($img_sec) = $text =~ /param image:\s*\d+\s+\d+\s+\d+\s*:=(.*?);/s;
fail('image section not found') unless defined $img_sec;
my %img;
for my $line (split /\n/, $img_sec) {
    next unless $line =~ /^\s*(\S+)\s+(\d)\s+(\d)\s+(\d)\s*$/;
    $img{$1} = [ $2 + 0, $3 + 0, $4 + 0 ];
}

my ($tgt_sec) = $text =~ /param target :=(.*?);/s;
fail('target not found') unless defined $tgt_sec;
my @tgt_tokens = $tgt_sec =~ /(\d+)/g;
fail('target must be 6 numbers') unless @tgt_tokens == 6;
my @target;
for (my $i = 0; $i < 6; $i += 2) {
    $target[ $tgt_tokens[$i] ] = $tgt_tokens[$i + 1];
}

sub word_gens {
    my ($w) = @_;
    return () if $w eq 'e';
    my $s = $w;
    my @g;
    while ($s =~ s/^s([12])//) {
        push @g, $1 + 0;
    }
    fail("cannot parse word $w") if $s ne '';
    return @g;
}

# Completeness: every positive word of length <= 3, exactly once.
my @all = ('e');
for my $len (1 .. 3) {
    my @prev = ('e');
    for my $pos (1 .. $len) {
        my @next;
        for my $w (@prev) {
            push @next, ($w eq 'e' ? '' : $w) . 's1', ($w eq 'e' ? '' : $w) . 's2';
        }
        @prev = @next;
    }
    push @all, @prev;
}
fail('word set mismatch: model has ' . scalar(keys %img) . ', expected ' . scalar(@all))
    unless scalar(keys %img) == scalar(@all);
for my $w (@all) {
    fail("word $w missing from image table") unless exists $img{$w};
    fail("word $w missing from len table") unless exists $len{$w};
}

for my $w (@all) {
    my @g = word_gens($w);
    my @p = permutation(@g);
    my $got = join ',', @p;
    my $want = join ',', @{ $img{$w} };
    fail("image[$w]: model says $want, permutation says $got") unless $got eq $want;
    fail("len[$w]: model says $len{$w}, word length " . scalar(@g))
        unless $len{$w} == scalar(@g);
}

# Optimum for the model's target, by independent S3 BFS.
my $tgt_key = join ',', @target;
my @q = ([0, 1, 2, 0]);
my %seen = ('0,1,2' => 1);
my $best = -1;
while (@q) {
    my ($a, $b, $c, $d) = @{ shift @q };
    if ("$a,$b,$c" eq $tgt_key) { $best = $d; last }
    next if $d >= 6;
    for my $i (0, 1) {
        my @p = ($a, $b, $c);
        @p[$i, $i + 1] = @p[$i + 1, $i];
        my $k = join ',', @p;
        next if $seen{$k}++;
        push @q, [ @p, $d + 1 ];
    }
}
fail("BFS could not reach target $tgt_key") if $best < 0;
my @achievers = sort grep { join(',', @{ $img{$_} }) eq $tgt_key } @all;
my $min_len = (sort { $len{$a} <=> $len{$b} } @achievers)[0];
fail("model achievers min length $len{$min_len}, BFS says $best")
    unless $len{$min_len} == $best;
print "AMPL_OK: " . scalar(@all) . " words verified, target $tgt_key "
    . "optimum length $best, achievers: " . join(',', @achievers) . "\n";
exit 0;
