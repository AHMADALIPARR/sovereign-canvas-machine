# ColorForth ceremony

The root supervisor is a block of nine words, in this order:

```
INTENT <id>
BRAID|QUANTUM|RECURRENCE <repo-relative proposal>
AXIOM
CONTRACT
PROVE
COMPILE
SEAL
TRACE
HALT
```

`bootstrap/run.pl` is the interpreter. A missing, reordered, or extra word is `REJECT: CEREMONY`. The proposal path may not be absolute and may not contain `..`. The INTENT word and the workspace word must match the record. SEAL appends one ledger line. TRACE writes the stage log to stderr. HALT returns the pipeline status.

There is no color display and no ColorForth binary. The ceremony is the authority schedule those words name.
