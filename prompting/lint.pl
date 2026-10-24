#!/usr/bin/perl
# Copyright (C) 2026 AHMAD ALI PARR
# Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../perl";
use SCM::Decode qw(decode);

my $text = do { local $/; <STDIN> };
my $d = decode($text // '');
if ($d->{ok}) {
    print "OK $d->{fields}{intent}\n";
    exit 0;
}
print "REJECT:$d->{error}\n";
exit 1;
