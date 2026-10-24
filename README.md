# Sovereign Canvas Machine (SCM-002)

![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)
![Status: Milestone 1](https://img.shields.io/badge/Status-Milestone%201-yellow.svg)
![Language: Perl 5](https://img.shields.io/badge/Language-Perl%205-green.svg)
![Language: AWK](https://img.shields.io/badge/Language-AWK-orange.svg)
![Policy: Deny by Default](https://img.shields.io/badge/Policy-Deny%20by%20Default-red.svg)
![Verification: Formal](https://img.shields.io/badge/Verification-Formal-purple.svg)

**Topics:** formal-verification · braid-group · prolog · perl5 · awk · mathematical-execution · sovereign-systems · proof-carrying-code · lean4 · compcert · hyperdag · colorforth · deny-by-default · canvas-protocol

---

## Overview

The Sovereign Canvas Machine (SCM-002) is a proof-carrying mathematical execution environment designed to enforce strict separation between untrusted model-generated proposals and authorized native execution. It implements a multi-layered architecture in which large language models may only submit bounded, typed proposals through a restricted Canvas protocol. Every subsequent stage—decoding, policy authorization, optimization, transformation, verification, compilation, and execution—is governed by independent, fail-closed mechanisms. No proposal becomes executable authority without explicit authorization and independently checked evidence.

This repository contains the Milestone 1 vertical slice: a working Perl 5 orchestrator, AWK decoder, typed Canvas protocol, and deny-by-default policy enforcer. The system accepts a valid three-strand braid fixture and rejects malformed or unauthorized proposals. All source files carry AGPLv3 headers. External components (QEMU-contained Ollama, Lean 4 + Mathlib, CompCert, full Prolog evaluation, ColorForth) are documented as blocked or deferred pending availability of the corresponding toolchains.

The design is motivated by the observation that conventional agent frameworks grant models direct tool access or shell execution. SCM-002 inverts this model. The model proposes; the Canvas constrains; AWK decodes; Perl orchestrates; Prolog authorizes; Virtual ADRs govern; AMPL optimizes; the HyperDAG represents; XSLT transforms; Lean verifies; CompCert compiles; ColorForth controls; QEMU contains; the ledger records. Each boundary is explicit, testable, and fail-closed.

## Architecture

### Control Plane

The control plane is implemented entirely in Perl 5 and AWK. The Perl supervisor owns the state machine, schema validation, timeout handling, resource accounting, and routing between stages. It never interpolates untrusted model output into shell commands. Subprocess execution uses argument vectors and explicitly controlled environments. The AWK decoder performs deterministic, bounded parsing of the line-oriented Canvas protocol. Maximum line length and record size are enforced before any further processing.

### Sovereign Canvas Protocol

The Canvas is the only interface through which an untrusted model may submit proposals. Records are line-oriented and versioned (SCM-CANVAS/1.0). Supported workspaces are BRAID, QUANTUM, and RECURRENCE. Every record must contain an intent identifier, workspace type, input digest, candidate representation, proposed transformations, resource estimates, proof obligations, and an UNVERIFIED status. Malformed, oversized, unknown, or unauthorized records are rejected before policy evaluation.

### Constitutional Policy

Authorization is deny-by-default. The Prolog source declares the required invariants. The model cannot mutate policy. Unrecognized operations are denied. For Milestone 1, a pure-Perl bootstrap enforcer mirrors these rules so that acceptance tests can run without an external Prolog interpreter.

### Mathematical Core (Deferred)

Milestone 2 will introduce a braid equivalence checker, an AMPL optimization model over three-strand generators, a typed Braided Causal HyperDAG intermediate representation, and Lean 4 + Mathlib proof obligation generation.

### Transformation and Compilation (Deferred)

Canonical XML intermediate representations will be transformed by terminating XSLT passes. A verified lowering path produces CompCert-compatible C/Clight. Compilation occurs in a trusted build environment outside the QEMU inference guest.

### Isolation and Authority (Deferred)

Ollama and Llama execute inside a QEMU guest with no model tool calls. ColorForth is the ultimate root supervisor.

### Ledger

An append-only hash-chained ledger records intent hashes, prompt-signature hashes, policy hashes, ADR digests, proof manifests, IR hashes, and binary hashes.

## Hard Boundaries

1. Model isolation. Llama cannot invoke tools or directly access host processes.
2. Mathematical authority. Prolog enforces permissions, AMPL handles optimization, and Lean checks proofs.
3. Native compilation. CompCert verifies its supported compilation transformations.

## Milestone Status

Milestone 1 (complete): Perl supervisor, AWK decoder, typed Canvas protocol, Prolog deny-by-default source, pure-Perl policy bootstrap, single braid fixture, and acceptance tests. 5/5 tests passed.

Milestone 2 (next): Braid equivalence, AMPL optimization model, HyperDAG representation, Lean proof obligation generator.

## Build and Test

```bash
cd sovereign-canvas-machine
make test
```

## License

This project is licensed under the GNU Affero General Public License v3.0. Copyright headers appear in every source file.

## Contact

AHMAD ALI PARR
SnapKitty Research Lab
Bel esprit D'accord Trust

---

*No model-generated proposal becomes executable authority without independent verification and explicit authorization.*
