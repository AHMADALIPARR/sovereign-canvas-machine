# Sovereign Canvas Machine (SCM-002)

![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)
![Policy: Deny by Default](https://img.shields.io/badge/Policy-Deny%20by%20Default-red.svg)

Proof-carrying mathematical execution. A model may submit one typed canvas record. It does not get a shell, a tool call, or the right to mark its own work verified. Two decoders must agree. Policy is deny-by-default. A second implementation, in C, must recompute the same invariant. Only then can the ColorForth ceremony seal a hash-chained ledger line.

Copyright (C) 2026 AHMAD ALI PARR. Licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE).

## What actually runs

`make test` executes all of the following. There is no separate "milestone 2" directory left as a placeholder.

| Stage | Where | Decision |
|---|---|---|
| Decode | `awk/canvas_decoder.awk` and `perl/SCM/Decode.pm` | Both must agree |
| ADR seal | `adr/DIGEST` | Digest mismatch rejects everything |
| Policy | `perl/SCM/Policy.pm` | Deny by default |
| Braid equality | Artin action on F3 | Faithful for B3, not string compare |
| Clifford equality | Tableau for H, X, Y, Z, S, SDG, CNOT, CZ | Up to global phase |
| Recurrence | Exact integer recomputation | Bound ±1e9 |
| Bound | Permutation BFS, or one-qubit Clifford distance | Can only reject |
| Hypergraph | `perl/SCM/HyperDAG.pm` | Diagram plus invariant |
| Projection | `xslt/canonicalize.xsl`, applied in Perl | Terminating |
| Native check | `compcert/scm_rt.c` compiled with gcc | Must match the Perl invariant |
| Ceremony | `bootstrap/run.pl` | Skipped word is a rejection |
| Ledger | `perl/SCM/Ledger.pm` | SHA-256 chain, tamper-evident |

Workspaces are `BRAID`, `QUANTUM`, and `RECURRENCE`. The record format is [schemas/canvas_protocol.md](schemas/canvas_protocol.md).

```bash
make test
```

Accept prints `ACCEPT: AUTHORIZED`. Anything else is a rejection and a non-zero status.

```bash
perl perl/scm_supervisor.pl < fixtures/braid_relation.txt
perl perl/policy_enforcer.pl BRAID 's1 s2 s1' 's2 s1 s2'
perl bootstrap/run.pl bootstrap/accept_braid.cf
```

The relation fixture is the one that used to be impossible here: target `s1 s2 s1`, candidate `s2 s1 s2`. Those are the same three-strand braid. `s1 s1 s2` is not, and it is denied.

## What is source, and is not executed in this bootstrap

These files are real and are not stubs. They are also not claimed to have been run, because those programs are not installed:

- `lean/Kernel.lean` — the same Artin check, for Lean 4, with `native_decide` on the braid relation and on inverse cancellation.
- `prolog/policy.pl` — the same check as a deny-by-default theory.
- `ampl/braid_perm.mod` — the permutation lower bound as an integer program. The executed bound is the BFS.
- CompCert. The C is written in a subset CompCert can compile. The bootstrap compiler is gcc, and an accept does not become a CompCert certificate because gcc succeeded.
- QEMU and Ollama. Both wrappers refuse to start. `net=none`, tools disabled, tool-call syntax denied.

## Boundaries

Untrusted bytes are not interpolated into a shell. Children are started with argument vectors. A proposal with STATUS other than `UNVERIFIED` is rejected. A path in the ceremony may not be absolute and may not contain `..`. The ADR digest is checked before a policy decision, so a silent edit of the constitution fails closed.

## License

GNU Affero General Public License v3.0 only. The full text is in [LICENSE](LICENSE).
