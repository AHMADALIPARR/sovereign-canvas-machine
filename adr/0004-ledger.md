# ADR 0004 — Hash-chained ledger

An accept may be sealed only by the ColorForth ceremony, which requires
the word SEAL. Each record stores the previous line's SHA-256. The
genesis previous-hash is 64 zero digits. Verification walks the chain
and rejects a changed line, a skipped index, or a broken link.
