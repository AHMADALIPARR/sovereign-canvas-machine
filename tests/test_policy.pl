# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;

my $POLICY = "/workspace/artifacts/sovereign-canvas-machine/perl/policy_enforcer.pl";

my $allow = `perl $POLICY BRAID 's1 s2 s1' 's1 s2 s1'`;
like($allow, qr/^ALLOW/, "Policy allows fixture equivalence");

my $deny = `perl $POLICY BRAID 's1 s2 s1' 's1 s1 s2'`;
like($deny, qr/^DENY/, "Policy denies untrusted transformation");

done_testing();
