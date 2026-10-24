#!/usr/bin/perl
# Copyright (C) 2026 AHMAD ALI PARR
# Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.

use strict;
use warnings;
use FindBin;
use File::Spec;
use Test::More;
use lib "$FindBin::Bin/../perl";

my $ROOT = File::Spec->rel2abs("$FindBin::Bin/..");
$ENV{SCM_ROOT} = $ROOT;
delete $ENV{SCM_SEAL};
delete $ENV{SCM_LEDGER};

use SCM::Decode qw(decode awk_decode fields_canon);
use SCM::Policy qw(decide_braid_words);
use SCM::Pipeline qw(run);
use SCM::Ledger qw(append verify);
use SCM::ADR qw(check);
use SCM::Braid qw(invariant parse_gens);
use SCM::Quantum qw(distance1 parse_gates tableau_key);
use SCM::Recurrence qw(evaluate);

sub slurp {
    my ($p) = @_;
    open my $fh, '<', $p or die "$p: $!";
    local $/;
    return scalar <$fh>;
}

opendir my $dh, "$ROOT/fixtures" or die $!;
my @fix = sort grep { /\.txt$/ } readdir $dh;
closedir $dh;
ok(@fix >= 10, 'fixtures present');

for my $name (@fix) {
    my $text = slurp("$ROOT/fixtures/$name");
    my $perl = decode($text);
    my $awk  = awk_decode($ROOT, $text);
    my $sp = $perl->{ok} ? fields_canon($perl->{fields}) : "ERR:$perl->{error}";
    my $sa = $awk->{ok}  ? fields_canon($awk->{fields})  : "ERR:$awk->{error}";
    is($sp, $sa, "decoders agree on $name");
}

my ($ok, $why) = decide_braid_words('BRAID', 's1 s2 s1', 's1 s2 s1');
ok($ok, "identical braid allowed ($why)");
($ok, $why) = decide_braid_words('BRAID', 's1 s2 s1', 's2 s1 s2');
ok($ok, "braid relation allowed ($why)");
($ok, $why) = decide_braid_words('BRAID', 's1 s2 s1', 's1 s1 s2');
ok(!$ok, "inequivalent braid denied ($why)");
($ok, $why) = decide_braid_words('BRAID', 's1 s2 s1', 's1 nope s2');
ok(!$ok, "bad generator denied ($why)");
($ok, $why) = decide_braid_words('NOPE', 's1', 's1');
ok(!$ok, 'unknown workspace denied');

my %expect = (
    'braid_valid.txt'             => 1,
    'braid_relation.txt'          => 1,
    'braid_inverse.txt'           => 1,
    'quantum_hzh.txt'             => 1,
    'quantum_cnot.txt'            => 1,
    'recurrence_fib.txt'          => 1,
    'braid_unauthorized.txt'      => 0,
    'braid_invalid_generator.txt' => 0,
    'braid_bad_cost.txt'          => 0,
    'braid_claimed_verified.txt'  => 0,
    'braid_inject.txt'            => 0,
    'quantum_neq.txt'             => 0,
    'recurrence_bad.txt'          => 0,
);

unlink '/tmp/scm-pwned';
for my $name (sort keys %expect) {
    my $text = slurp("$ROOT/fixtures/$name");
    my $r = run($text, root => $ROOT);
    if ($expect{$name}) {
        is($r->{code}, 0, "$name accepted");
        like($r->{line}, qr/^ACCEPT: AUTHORIZED\n/, "$name accept line");
    } else {
        is($r->{code}, 1, "$name rejected");
        like($r->{line}, qr/^REJECT: /, "$name reject line");
    }
}
ok(!-e '/tmp/scm-pwned', 'metacharacters were not passed to a shell');

is(evaluate(2, [1, 1], [0, 1], 10), 55, 'fibonacci recomputed');
is(distance1(parse_gates('X:0', 1)), 1, 'X is one gate from identity');
is(distance1(parse_gates('H:0 H:0', 1)), 0, 'H H is identity');

my ($adr_ok, $adr) = check($ROOT);
ok($adr_ok, "ADR seal $adr");

my $ledger = "/tmp/scm-ledger-$$.jsonl";
unlink $ledger;
my %base = (
    time => '2026-10-24T00:00:00Z', intent => 'SCM-TEST-1',
    proposal => 'a' x 64, policy => 'b' x 64, adr => 'c' x 64,
    cert => 'd' x 64, ir => 'e' x 64, binary => 'f' x 64, decision => 'ALLOW',
);
append($ledger, \%base);
$base{intent} = 'SCM-TEST-2';
append($ledger, \%base);
my ($lok, $lwhy) = verify($ledger);
ok($lok, "ledger verifies ($lwhy)");
open my $lf, '+<', $ledger or die $!;
seek $lf, 10, 0;
print {$lf} 'X';
close $lf;
($lok, $lwhy) = verify($ledger);
ok(!$lok, "tampered ledger fails ($lwhy)");
unlink $ledger;

my $sealed = "/tmp/scm-seal-$$.jsonl";
unlink $sealed;
local $ENV{SCM_LEDGER} = $sealed;
local $ENV{SCM_NOW}    = '2026-10-24T00:00:01Z';
my $cout = `perl $ROOT/bootstrap/run.pl bootstrap/accept_braid.cf`;
is($?, 0, 'colorforth ceremony accepts');
like($cout, qr/^ACCEPT: AUTHORIZED/, 'ceremony line');
($lok, $lwhy) = verify($sealed);
ok($lok, "sealed ledger ($lwhy)");
unlink $sealed;

my $badc = `perl $ROOT/bootstrap/run.pl bootstrap/bad_order.cf`;
is($? >> 8, 1, 'skipped word is rejected');
like($badc, qr/CEREMONY/, 'ceremony error');

my $q1 = system('sh', "$ROOT/qemu/run-guest.sh");
is($q1 >> 8, 1, 'qemu refuses to boot');
my $q2 = system('sh', "$ROOT/qemu/run-guest.sh", '-net', 'user');
is($q2 >> 8, 2, 'qemu refuses a net device');

my $tool = `printf '%s' '{"tool_calls":[]}' | perl $ROOT/ollama/wrap.pl`;
like($tool, qr/model_tool_syntax/, 'tool syntax denied');
my $plain = `printf '%s' 'hello' | perl $ROOT/ollama/wrap.pl`;
like($plain, qr/ollama_not_authorized/, 'model launch denied');

sub c_quote { join(', ', @{ $_[0] }) }

my @gens = (1, -1, 2, -2);
my @cases;
for my $a (@gens) {
    push @cases, [ $a ];
    for my $b (@gens) { push @cases, [ $a, $b ] }
}
my $src = <<'C';
#include "scm_rt.h"
#include <stdio.h>
#include <string.h>
static int one(const int *w, int n, const char *expect) {
    char buf[4096];
    if (scm_braid_invariant(w, n, buf, 4096) != 0) return 1;
    if (strcmp(buf, expect) != 0) {
        fprintf(stderr, "mismatch %s vs %s\n", buf, expect);
        return 1;
    }
    return 0;
}
int main(void) {
C
my $i = 0;
for my $w (@cases) {
    my $exp = invariant(@$w);
    $src .= "    { int w[] = { " . c_quote($w) . " }; if (one(w, " . scalar(@$w) . ", \"$exp\")) return 1; }\n";
    $i++;
}
$src .= "    return 0;\n}\n";
my $cfile = "/tmp/scm-cross-$$.c";
open my $cf, '>', $cfile or die $!;
print {$cf} $src;
close $cf;
my $bin = "/tmp/scm-cross-$$";
my $gcc = system('gcc', '-std=c99', '-Wall', '-Werror', '-O2',
    '-I', "$ROOT/compcert", '-o', $bin, $cfile, "$ROOT/compcert/scm_rt.c");
is($gcc, 0, 'cross-check runtime compiles');
is(system($bin), 0, "C matches Perl on $i braid words");
unlink $cfile, $bin;

my $self = system('gcc', '-std=c99', '-Wall', '-Werror', '-O2',
    '-I', "$ROOT/compcert", '-o', '/tmp/scm-selftest',
    "$ROOT/compcert/selftest.c", "$ROOT/compcert/scm_rt.c");
is($self, 0, 'selftest compiles');
my $sout = `/tmp/scm-selftest`;
like($sout, qr/SELFTEST_OK/, 'fixed identities hold in C');
unlink '/tmp/scm-selftest';

done_testing();
