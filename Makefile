# Copyright (C) 2026 AHMAD ALI PARR
# Sovereign Canvas Machine — Makefile
# Licensed under the GNU Affero General Public License v3.0.

.PHONY: test clean

test:
	@echo "=== SCM Milestone 1 Tests ==="
	@perl tests/test_canvas_protocol.pl
	@perl tests/test_policy.pl
	@echo "=== Tests complete ==="

clean:
	rm -rf /tmp/scm-test-*
