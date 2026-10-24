# ADR seal

`0001` through `0005` are the constitutional records. `DIGEST` is the SHA-256 of those files in name order. `perl/SCM/ADR.pm` recomputes it. A mismatch rejects every proposal before policy runs.
