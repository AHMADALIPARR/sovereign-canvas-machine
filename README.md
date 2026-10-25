# Sovereign Canvas Machine (SCM-002)

![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)
![Policy: Deny by Default](https://img.shields.io/badge/Policy-Deny%20by%20Default-red.svg)
![Tests](https://img.shields.io/badge/tests-104%2F104-brightgreen.svg)
![Ingress](https://img.shields.io/badge/ingress-Unix%20socket%20%2B%20REPL-informational.svg)
![GGUF](https://img.shields.io/badge/model-Snapkitty%2Fsnapkitty--merged-orange.svg)
![PHP](https://img.shields.io/badge/PHP-8%2B-777BB4.svg)
![Perl](https://img.shields.io/badge/Perl-5.32%2B-39457E.svg)
![Language](https://img.shields.io/badge/workspaces-BRAID%20%7C%20QUANTUM%20%7C%20RECURRENCE-purple.svg)

Proof-carrying mathematical execution. A model may submit **one** typed canvas record. It does not get a shell, a tool call, or the right to mark its own work verified. Two decoders must agree. Policy is deny-by-default. A second implementation, in C, must recompute the same invariant. Only then can the ColorForth ceremony seal a hash-chained ledger line.

Copyright (C) 2026 AHMAD ALI PARR. Licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE).

---

## REPL demo

Interactive Read–Eval–Print loop over the pipeline (`ingress/repl.php`):

![REPL demo](docs/demo/repl-demo.gif)

```text
scm> file fixtures/braid_valid.txt
ACCEPT: AUTHORIZED

scm> file fixtures/braid_unauthorized.txt
REJECT: POLICY:no_trusted_equivalence

scm> propose
... SCM-CANVAS/1.0
... TARGET s1 s2 s1
... CANDIDATE s2 s1 s2
... END
ACCEPT: AUTHORIZED
```

```bash
make repl                    # direct mode (no socket)
php ingress/repl.php --direct

# or with the Unix-socket server
php ingress/server.php &
php ingress/repl.php
```

### REPL commands

| Command | Action |
|---|---|
| `help` | List commands |
| `file <rel/path>` | Propose a canvas file (e.g. `fixtures/braid_valid.txt`) |
| `propose` | Multi-line paste until `END` |
| `generate [model]` | GGUF generate (default `snapkitty-merged.Q4_K_M.gguf`) |
| `register <name> <abs>` | Register a local `.gguf` |
| `models` | List registered weights |
| `ping` | Health check |
| `json {...}` | Raw JSON op |
| `quit` | Exit |

Paste a full `SCM-CANVAS/1.0` … `END` record at the prompt; the loop reads until `END` and evaluates it.

---

## What the loop is made of

### Read → Eval → Print (REPL)

```mermaid
flowchart LR
  subgraph READ
    A[stdin / paste] --> B{Starts with<br/>SCM-CANVAS/1.0?}
    B -->|yes| C[Read lines until END]
    B -->|no| D[Parse command]
    D --> E[file / propose / generate / …]
  end

  subgraph EVAL
    C --> F[Normalize canvas]
    E --> G{op}
    G -->|propose / file| F
    G -->|generate| H[llama-cli + system prompt]
    H --> I[Extract first canvas]
    I --> F
    F --> J[Pipeline]
  end

  subgraph PRINT
    J --> K{Decision}
    K -->|ok| L["ACCEPT: AUTHORIZED"]
    K -->|fail| M["REJECT: …"]
    L --> N[stdout]
    M --> N
  end
```

### Pipeline (eval stages)

```mermaid
flowchart TB
  IN[Canvas record<br/>STATUS must be UNVERIFIED] --> D1

  subgraph Decode
    D1[Perl SCM::Decode]
    D2[AWK canvas_decoder]
    D1 --> AGREE{Fields agree?}
    D2 --> AGREE
  end

  AGREE -->|no| R1[REJECT: DECODER_*]
  AGREE -->|yes| ADR

  ADR[ADR digest seal] -->|mismatch| R2[REJECT: ADR_SEAL]
  ADR -->|ok| POL

  POL[Policy deny-by-default] -->|denied| R3[REJECT: POLICY:…]
  POL -->|ok| MATH

  subgraph Math
    MATH[Braid Artin / Quantum tableau / Recurrence]
    BOUND[Bound: permutation BFS or Clifford distance]
  end

  MATH --> BOUND
  BOUND -->|reject only| R4[REJECT: OPT:…]
  BOUND --> HD

  HD[HyperDAG + Merkle XML] --> XSLT[xsltproc canonicalize]
  XSLT -->|fail| R5[REJECT: XSLT_FAIL]
  XSLT --> C[Native C recomputation]
  C -->|mismatch| R6[REJECT: NATIVE]
  C -->|match| CER

  CER[Ceremony optional] --> LED[Ledger append SHA-256]
  LED --> OK[ACCEPT: AUTHORIZED]
```

### Production ingress topology

```mermaid
flowchart TB
  subgraph Proposers
    HUMAN[Human / REPL]
    GGUF[Local GGUF<br/>snapkitty-merged]
    EXT[External process]
  end

  HUMAN -->|file / paste / generate| REPL[ingress/repl.php]
  GGUF -->|register + generate| SOCK
  EXT -->|raw or JSON| SOCK
  REPL -->|--direct| SUP[perl scm_supervisor.pl]
  REPL -->|socket| SOCK[Unix socket<br/>run/scm.sock]
  SOCK --> SRV[ingress/server.php]
  SRV --> SUP
  SUP --> PIPE[SCM::Pipeline]
  PIPE --> LEDGER[(Ledger chain)]
```

### GGUF path (default model)

```mermaid
sequenceDiagram
  participant U as User
  participant F as fetch_snapkitty_merged.sh
  participant S as ingress server
  participant L as llama-cli
  participant P as Pipeline

  U->>F: download + SHA-256 verify
  F->>F: snapkitty-merged.Q4_K_M.gguf
  U->>S: register_gguf (local path only)
  U->>S: generate
  S->>L: system_prompt + no tools
  L-->>S: model text
  S->>S: extract SCM-CANVAS … END
  S->>P: same propose path
  P-->>U: ACCEPT / REJECT
```

---

## Quick start

```bash
# tests (needs xsltproc + gcc)
make test                 # 104/104
make test-ingress         # socket smoke tests

# REPL
make repl

# Unix-socket server
php ingress/server.php
php ingress/client.php --file fixtures/braid_valid.txt

# Default GGUF (outside trust boundary)
./models/fetch_snapkitty_merged.sh --register
php ingress/client.php --json '{"op":"generate","model":"snapkitty-merged.Q4_K_M.gguf"}'
```

Accept prints `ACCEPT: AUTHORIZED`. Anything else is a rejection and a non-zero status.

```bash
perl perl/scm_supervisor.pl < fixtures/braid_relation.txt
perl perl/policy_enforcer.pl BRAID 's1 s2 s1' 's2 s1 s2'
perl bootstrap/run.pl bootstrap/accept_braid.cf
```

The relation fixture is the one that used to be impossible under string compare: target `s1 s2 s1`, candidate `s2 s1 s2` — the same three-strand braid. `s1 s1 s2` is not, and it is denied.

---

## What actually runs

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
| Projection | `xslt/canonicalize.xsl` via `xsltproc` | Terminating |
| Native check | `compcert/scm_rt.c` compiled with gcc | Must match the Perl invariant |
| Ceremony | `bootstrap/run.pl` | Skipped word is a rejection |
| Ledger | `perl/SCM/Ledger.pm` | SHA-256 chain, tamper-evident |
| Ingress | `ingress/server.php` | One propose → pipeline |
| REPL | `ingress/repl.php` | Interactive read–eval–print |

Workspaces are `BRAID`, `QUANTUM`, and `RECURRENCE`. Record format: [schemas/canvas_protocol.md](schemas/canvas_protocol.md).

---

## Production ingress & model

Unix-domain socket (PHP). One request → one accept/reject + ledger line.

- Raw canvas body or JSON: `op=propose|generate|register_gguf|ping|list_models`
- Default weights: **[Snapkitty/snapkitty-merged](https://huggingface.co/Snapkitty/snapkitty-merged)** (`snapkitty-merged.Q4_K_M.gguf`, SHA-256 verified by `models/fetch_snapkitty_merged.sh`)
- **No HTTP download inside ingress** — fetch is a separate, auditable step
- QEMU and Ollama dirs are **deprecated** fail-closed shims; isolation notes in `sandbox/`

See [ingress/README.md](ingress/README.md) and [models/README.md](models/README.md).

---

## Source present, not claimed executed here

These files are real and are not stubs. They are not claimed to have been run when the toolchain is absent:

- `lean/Kernel.lean` — Artin check for Lean 4
- `prolog/policy.pl` — deny-by-default theory
- `ampl/braid_perm.mod` — permutation bound as an integer program (executed bound is the BFS)
- CompCert-friendly C (bootstrap compiler is gcc)

---

## Boundaries

Untrusted bytes are not interpolated into a shell. Children are started with argument vectors. A proposal with `STATUS` other than `UNVERIFIED` is rejected. Paths may not be absolute and may not contain `..`. The ADR digest is checked before policy, so a silent edit of the constitution fails closed.

---

## License

GNU Affero General Public License v3.0 only. The full text is in [LICENSE](LICENSE).
