# ADR 0001 — Deny by default

Unrecognized workspaces, missing obligations, malformed records, and
inequivalent candidates are denied. There is no allow-if-unknown clause.
The model cannot rewrite this rule. A proposal whose STATUS is anything
other than UNVERIFIED is rejected before policy.
