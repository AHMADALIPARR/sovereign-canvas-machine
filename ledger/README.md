# Ledger

Append-only SHA-256 chain. The previous field of each line is the hash of the previous line. Genesis is 64 zero digits. `perl/SCM/Ledger.pm` appends and verifies. The chain file is runtime state and is not part of the source tree.
