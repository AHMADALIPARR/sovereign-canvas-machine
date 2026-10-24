# Copyright (C) 2026 AHMAD ALI PARR
# Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: test clean

test:
	cd $(ROOT) && perl tests/suite.pl

clean:
	rm -rf $(ROOT)/build $(ROOT)/ledger/chain.jsonl
