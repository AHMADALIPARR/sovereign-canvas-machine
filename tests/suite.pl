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
use SCM::Braid qw(invariant parse_gens exact_braid_equal matrix_invariant exponent_sum);
use SCM::Quantum qw(distance1 parse_gates tableau_key inverse_circuit);
use SCM::Recurrence qw(evaluate sequence);
use SCM::Optimize qw(optimize_exact);
use SCM::HyperDAG qw(verify_xml_hashes);

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

# --- Completion: identity, cross-checks, Merkle XML, AMPL, Lean, ceremony ---

# Identity is a word, not an error (strict-parse fix).
($ok, $why) = decide_braid_words('BRAID', '', '');
ok($ok, "identity braid allowed ($why)");
($ok, $why) = decide_braid_words('BRAID', '', 's1');
ok(!$ok, "identity vs s1 denied ($why)");
ok(SCM::Quantum::equivalent(1, [], []), 'identity circuit allowed');
ok(!SCM::Quantum::equivalent(1, [], [parse_gates('X:0', 1)]), 'identity vs X denied');

# Matrix cross-check on the Artin invariant, including the kernel collision.
ok(exact_braid_equal('s1 s2 s1', 's2 s1 s2'), 'matrix+expsum agrees on braid relation');
my $half = 's1 s2 s1 s1 s2 s1';
my $kernel = join ' ', ($half, $half, $half, $half);
my @kg = parse_gens($kernel);
ok(!exact_braid_equal($kernel, ''), 'kernel word is not identity');
is(matrix_invariant(@kg), matrix_invariant(), 'kernel word has identity matrix');
is(exponent_sum(@kg), 24, 'kernel word has exponent sum 24');

# Exact optimizer (Optimize stage beyond necessary-condition bounds).
my ($ost, $ow, $oc, $ox) = optimize_exact('s1 s2 s1', {s1 => 2, s2 => 1}, 3, 1000);
is($ost, 'OPTIMAL_WITHIN_BOUNDS', 'exact optimizer completes');
is($ow, 's2,s1,s2', 'exact optimizer selects s2,s1,s2');
is($oc, 4, 'exact optimizer cost 4');
($ost, $ow, $oc, $ox) = optimize_exact('s1 s2 s1', {s1 => 2, s2 => 1}, 3, 32);
is($ost, 'INCOMPLETE_SEARCH', 'exact optimizer reports budget exhaustion');
is($ow, 's1,s2,s1', 'exact optimizer keeps best valid candidate');
is($oc, 5, 'exact optimizer best cost 5');

# Recurrence sequence + quantum inverse.
is_deeply(sequence(2, [1, 1], [0, 1], 10), [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55], 'fibonacci sequence');
my @qc = parse_gates('H:0 S:0 CNOT:0:1', 2);
my $qinv = inverse_circuit(\@qc);
ok(SCM::Quantum::equivalent(2, [ @qc, @$qinv ], []), 'circuit times inverse is identity');

# Merkle XML tree: full diagram, self-verifying, XSLT projection real.
my $vtext = slurp("$ROOT/fixtures/braid_valid.txt");
my $vr = run($vtext, root => $ROOT);
like($vr->{xml}, qr/<diagram>/, 'xml carries the diagram');
like($vr->{xml}, qr/<anyon /, 'xml carries anyon trajectories');
like($vr->{xml}, qr/<merkle root="[0-9a-f]{64}"/, 'xml carries the merkle root');
my ($xmok, $xmwhy) = verify_xml_hashes($vr->{xml});
ok($xmok, "xml merkle verifies ($xmwhy)");
like(join("\n", @{ $vr->{trace} }), qr/^xml=[0-9a-f]{64}$/m, 'trace carries xml hash');
like(join("\n", @{ $vr->{trace} }), qr/^xslt=[0-9a-f]{64}$/m, 'trace carries xslt hash');
like(join("\n", @{ $vr->{trace} }), qr/^merkle=[0-9a-f]{64}$/m, 'trace carries merkle root');
my $tampered = $vr->{xml};
$tampered =~ s/sign="1"/sign="2"/;
my ($tmok) = verify_xml_hashes($tampered);
ok(!$tmok, 'tampered xml fails merkle verification');
my $xfile = "/tmp/scm-xml-$$.xml";
open my $xf, '>', $xfile or die $!;
print {$xf} $vr->{xml};
close $xf;
my $xout = `xsltproc $ROOT/xslt/canonicalize.xsl $xfile`;
is($? >> 8, 0, 'xsltproc projects the tree');
like($xout, qr/<invariant>1,2,3,-2,-1;1,2,-1;1<\/invariant>/, 'xslt certificate carries the invariant');
unlink $xfile;

# AMPL contract verified against the executed implementation.
my $vout = `perl $ROOT/perl/verify_ampl.pl`;
is($? >> 8, 0, 'AMPL model verified against Perl BFS');

# Lean kernel typechecks where Lean exists.
my $lean = '';
for my $dir (split /:/, $ENV{PATH}) {
    if (-x "$dir/lean") { $lean = "$dir/lean"; last }
}
$lean = "$ENV{HOME}/.elan/bin/lean" if !$lean && -x "$ENV{HOME}/.elan/bin/lean";
if ($lean) {
    is(system($lean, "$ROOT/lean/Kernel.lean"), 0, 'Kernel.lean typechecks');
} else {
    pass('lean not installed; kernel check skipped');
}

# Unknown obligations grant nothing.
my $utext = slurp("$ROOT/fixtures/braid_valid.txt");
$utext =~ s/RP-002/RP-999/;
my $ur = run($utext, root => $ROOT);
is($ur->{code}, 1, 'unknown obligation rejected');
like($ur->{line}, qr/^REJECT: POLICY:unknown_obligation/, 'unknown obligation line');

# Ceremony fixtures beyond the original two.
for my $cf (qw(accept_quantum accept_recurrence)) {
    my $sealed2 = "/tmp/scm-seal2-$$.jsonl";
    unlink $sealed2;
    local $ENV{SCM_LEDGER} = $sealed2;
    local $ENV{SCM_NOW} = '2026-10-24T00:00:03Z';
    my $cout2 = `perl $ROOT/bootstrap/run.pl bootstrap/$cf.cf`;
    is($? >> 8, 0, "$cf ceremony accepts");
    like($cout2, qr/^ACCEPT: AUTHORIZED/, "$cf ceremony line");
    my ($lok2) = verify($sealed2);
    ok($lok2, "$cf sealed ledger verifies");
    unlink $sealed2;
}
my $badc2 = `perl $ROOT/bootstrap/run.pl bootstrap/bad_intent.cf`;
like($badc2, qr/CEREMONY:intent_mismatch/, 'bad intent ceremony rejected');
my $extra = `perl $ROOT/bootstrap/run.pl bootstrap/extra_word.cf`;
like($extra, qr/CEREMONY/, 'extra word ceremony rejected');
my $miss = `perl $ROOT/bootstrap/run.pl bootstrap/missing_word.cf`;
like($miss, qr/CEREMONY/, 'missing word ceremony rejected');

done_testing();
