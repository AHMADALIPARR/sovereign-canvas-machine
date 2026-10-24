# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 3;

my $BASE = "/workspace/artifacts/sovereign-canvas-machine";
my $SUPER = "$BASE/perl/scm_supervisor.pl";

sub run_supervisor {
    my ($file) = @_;
    my $output = `cat "$file" | perl $SUPER 2>&1`;
    my $exit = $? >> 8;
    return $exit;
}

my $exit_valid = run_supervisor("$BASE/fixtures/braid_valid.txt");
is($exit_valid, 0, "Valid braid proposal accepted");

my $exit_invalid = run_supervisor("$BASE/fixtures/braid_invalid_generator.txt");
is($exit_invalid, 1, "Invalid generator rejected");

my $exit_unauth = run_supervisor("$BASE/fixtures/braid_unauthorized.txt");
is($exit_unauth, 1, "Unauthorized transformation rejected");

done_testing();
