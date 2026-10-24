#!/usr/bin/perl
# Copyright (C) 2026 AHMAD ALI PARR
# Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
# Rejects tool-call syntax. Does not start a model.

use strict;
use warnings;
my $text = do { local $/; <STDIN> };
$text = '' unless defined $text;
if ($text =~ /tool_calls|<tool|function_call|"tools"\s*:/i) {
    print "DENY:model_tool_syntax\n";
    exit 1;
}
print "DENY:ollama_not_authorized\n";
exit 1;
