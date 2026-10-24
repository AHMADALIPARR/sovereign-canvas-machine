# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

#!/usr/bin/perl
# policy_enforcer.pl — Pure-Perl deny-by-default enforcer for Milestone 1
# Mirrors Prolog policy; full Prolog evaluation requires external interpreter

use strict;
use warnings;

my ($workspace, $target, $candidate) = @ARGV;

# Allowed generators
my %generators = map { $_ => 1 } qw(s1 s2 s1_inv s2_inv);

sub valid_word {
    my ($word) = @_;
    return 0 unless defined $word;
    my @gens = split /\s+/, $word;
    return 0 unless @gens;
    for my $g (@gens) {
        return 0 unless $generators{$g};
    }
    return 1;
}

# Deny by default
unless ($workspace && $workspace eq "BRAID") {
    print "DENY:unknown_workspace\n";
    exit 1;
}

unless (valid_word($target) && valid_word($candidate)) {
    print "DENY:invalid_word\n";
    exit 1;
}

# Simple equivalence check for the fixture (s1 s2 s1 is the target)
# In full system this comes from Lean or trusted checker
if ($target eq "s1 s2 s1" && $candidate eq "s1 s2 s1") {
    print "ALLOW:fixture_equivalence\n";
    exit 0;
}

print "DENY:no_trusted_equivalence\n";
exit 1;
