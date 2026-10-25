# Copyright (C) 2026 AHMAD ALI PARR
# Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: test test-ingress clean ingress

test:
	cd $(ROOT) && perl tests/suite.pl

test-ingress:
	cd $(ROOT) && php tests/test_ingress.php

ingress:
	cd $(ROOT) && php ingress/server.php

clean:
	rm -rf $(ROOT)/build $(ROOT)/run/scm.sock $(ROOT)/ledger/chain.jsonl
