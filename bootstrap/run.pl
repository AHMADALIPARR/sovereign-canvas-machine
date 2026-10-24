#!/usr/bin/perl
# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

# ColorForth bootstrap. The block is the root ceremony. A skipped word
# never reaches the pipeline. SEAL is what appends the ledger.

use strict;
use warnings;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/../perl";
use SCM::Decode qw(decode);
use SCM::Pipeline qw(run);

my $root = File::Spec->rel2abs("$FindBin::Bin/..");
$ENV{SCM_ROOT} = $root;

my $block_path = shift @ARGV or die "usage: run.pl <block>\n";
die "DENY:path\n" if $block_path =~ m{^/} || $block_path =~ /\.\./;
my $abs = File::Spec->rel2abs($block_path, $root);
die "DENY:path\n" unless $abs eq $root || index($abs, $root . '/') == 0;
open my $bf, '<', $abs or die $!;
my $block = do { local $/; <$bf> };
close $bf;

my @lines = split /\n/, $block, -1;
pop @lines if @lines && $lines[-1] eq '';
my @need = qw(AXIOM CONTRACT PROVE COMPILE SEAL TRACE HALT);
if (@lines != 9 || $lines[0] !~ /^INTENT (SCM-[A-Z0-9-]+)\z/) {
    _halt('bad_ceremony');
}
my $intent = $1;
if ($lines[1] !~ /^(BRAID|QUANTUM|RECURRENCE) ([A-Za-z0-9_\/.-]+)\z/) {
    _halt('bad_ceremony');
}
my ($word, $rel) = ($1, $2);
if ($rel =~ m{^/} || $rel =~ /\.\./) {
    _halt('path');
}
for my $i (0 .. $#need) {
    _halt('bad_ceremony') unless $lines[ $i + 2 ] eq $need[$i];
}
my $proposal = File::Spec->catfile($root, split m{/}, $rel);
_halt('path') unless -f $proposal;
open my $pf, '<', $proposal or _halt('path');
my $text = do { local $/; <$pf> };
close $pf;
my $decoded = decode($text);
_halt('proposal') unless $decoded->{ok};
_halt('intent_mismatch') unless $decoded->{fields}{intent} eq $intent;
_halt('workspace_mismatch') unless $decoded->{fields}{workspace} eq $word;

my $r = run(
    $text,
    root  => $root,
    seal  => 1,
    ledger => ($ENV{SCM_LEDGER} // "$root/ledger/chain.jsonl"),
);
print $r->{line};
if (grep { $_ eq 'TRACE' } @lines) {
    print STDERR $_, "\n" for @{ $r->{trace} };
}
exit $r->{code};

sub _halt {
    my ($why) = @_;
    print "REJECT: CEREMONY:$why\n";
    exit 1;
}
