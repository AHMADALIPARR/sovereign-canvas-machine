#!/usr/bin/perl
# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use SCM::Policy qw(decide_braid_words);

# Three-argument form is the braid oracle used by the unit tests:
#   perl policy_enforcer.pl BRAID '<target>' '<candidate>'
# It does not consult a shell and does not grant authority by itself.

if (@ARGV != 3) {
    print "DENY:usage\n";
    exit 1;
}
my ($ok, $reason) = decide_braid_words(@ARGV);
if ($ok) {
    print "ALLOW:$reason\n";
    exit 0;
}
print "DENY:$reason\n";
exit 1;
