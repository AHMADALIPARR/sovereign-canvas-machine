# Delivery

The first push of this repository was a vertical slice in name only: the policy oracle string-compared one fixture, the supervisor interpolated untrusted fields into a shell, tests pointed at a path that does not exist, and every other directory was a two-line placeholder.

This revision replaces that with an executable deny-by-default pipeline.

What runs, and is covered by `make test`:

- Independent AWK and Perl decoders. Disagreement is a rejection.
- Artin equivalence for the three-strand braid group, not string equality. `s1 s2 s1` is accepted as `s2 s1 s2`. `s1 s1 s2` is denied.
- Clifford tableau equivalence for H, X, Y, Z, S, SDG, CNOT, and CZ.
- Exact integer recomputation of linear recurrences.
- A permutation / Clifford-distance bound that can only reject.
- A braided causal hypergraph and a canonical XML projection.
- A second implementation of each invariant in C, compiled with gcc, required to match.
- An append-only hash-chained ledger and an ADR digest checked before policy.
- A ColorForth ceremony that refuses a skipped word.
- Fail-closed QEMU and Ollama wrappers that do not boot anything.

What is present as source and is not executed here, because the toolchain is absent:

- The Lean 4 kernel (`lean/Kernel.lean`).
- The Prolog theory (`prolog/policy.pl`).
- The AMPL model (`ampl/braid_perm.mod`).
- A CompCert compilation. The C is in a CompCert-friendly subset; gcc is the bootstrap compiler and is labeled as such.

`make test` is the acceptance run. Do not cite an older 5/5 result.
