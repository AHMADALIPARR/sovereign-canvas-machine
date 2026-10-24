#!/usr/bin/perl
# Copyright (C) 2026 AHMAD ALI PARR
# Delegates to the full suite. Kept so older invocations still run the checks.
use strict;
use warnings;
use FindBin;
exec 'perl', "$FindBin::Bin/suite.pl";
