#!/usr/bin/perl
# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use SCM::Pipeline qw(run);

my $root = $FindBin::Bin;
$root =~ s{/perl\z}{};
$ENV{SCM_ROOT} = $root;

my $text = do { local $/; <STDIN> };
$text = '' unless defined $text;
my $r = run($text, root => $root);
print $r->{line};
if ($ENV{SCM_TRACE}) {
    print STDERR $_, "\n" for @{ $r->{trace} };
}
exit $r->{code};
