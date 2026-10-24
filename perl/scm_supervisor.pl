# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

#!/usr/bin/perl
# scm_supervisor.pl — Minimal Perl orchestrator for Milestone 1
# Responsibilities: schema validation, routing, state machine, policy gate

use strict;
use warnings;
use File::Basename;

my $BASE = dirname($0) . "/..";
my $AWK  = "$BASE/awk/canvas_decoder.awk";
my $POLICY = "$BASE/perl/policy_enforcer.pl";

sub decode_canvas {
    my ($input) = @_;
    my $tmp = "/tmp/scm-decode-$$.txt";
    open my $out, ">", $tmp or die "Cannot write temp: $!";
    open my $pipe, "| awk -f $AWK > $tmp" or die "Cannot start AWK: $!";
    print $pipe $input;
    close $pipe;
    open my $res, "<", $tmp or die $!;
    my @lines = <$res>;
    close $res;
    unlink $tmp;
    return @lines;
}

sub validate_and_authorize {
    my ($decoded) = @_;
    my %fields;
    for my $line (@$decoded) {
        chomp $line;
        if ($line =~ /^ERROR:(.*)/) {
            return (0, "DECODE_ERROR:$1");
        }
        if ($line =~ /^([^=]+)=(.*)/) {
            $fields{$1} = $2;
        }
    }
    return (0, "MISSING_FIELDS") unless $fields{intent} && $fields{workspace} && $fields{status};

    # Policy check
    my $policy_result = `perl $POLICY '$fields{workspace}' '$fields{target}' '$fields{candidate}' 2>&1`;
    chomp $policy_result;
    if ($policy_result !~ /^ALLOW/) {
        return (0, "POLICY_DENY:$policy_result");
    }
    return (1, "AUTHORIZED");
}

# Main: read from stdin
my $input = do { local $/; <STDIN> };

my @decoded = decode_canvas($input);
my ($ok, $msg) = validate_and_authorize(\@decoded);
print $ok ? "ACCEPT: $msg\n" : "REJECT: $msg\n";
exit($ok ? 0 : 1);
