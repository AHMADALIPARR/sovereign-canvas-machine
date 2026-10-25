# Completion report — sovereign-canvas-machine, 2026-10-24

Branch: `completion`, from origin/main `28ab04d` ("Replace the stub pipeline
with a deny-by-default machine"). Nothing here is pushed: publication still
needs the owner's go-ahead and a fresh single-use token, as always.

## Scope, as corrected by the owner

The F+ grade that opened this work was for a previous agent's work, not for
this repo's Milestone 2, which the owner never saw because it was never
pushed (local branch `main`, commit `2539e8c`, built on the old `eb92d72`
base). The corrected order: the Perl pipeline is good, the Lean kernel is
solid, everything else was the stubbed mess to finish — and the HyperDAG
was specified as a full canonical XML tree, Merkle DAG, with braid anyons.

What was kept intact: the deny-by-default architecture, the dual-decode
pipeline, the Artin/Clifford/recurrence checkers, the C runtime, the
ceremony interpreter, the ledger, and the ADR seal. What was fixed or
completed is below. No module was rewritten wholesale; no semantics were
changed except the three bugs listed, each of which was verified against
the source before being touched.

## Verified bugs fixed (all in the Perl, all real)

1. **Empty-word equivalence.** `SCM::Braid::equivalent`,
   `SCM::Quantum::equivalent`, and `SCM::Policy::decide_braid_words` /
   `_braid` / `_quantum` rejected empty words outright, so the identity
   could never be equivalent to anything, including itself. Root cause:
   the parsers could not distinguish a failed parse from the empty word.
   Fix: `parse_gens_strict` / `parse_gates_strict` return undef on an
   invalid token and an array reference otherwise (empty reference for
   the empty word); all equivalence paths use them. Decode-validated
   pipeline input is unaffected (the decoders require non-empty words).
2. **XML escaping was a no-op.** `Pipeline::_xe` replaced each
   metacharacter with itself. The stub XML writer that used it is gone;
   the real serializer (`SCM::HyperDAG::canon_xml`) escapes correctly,
   ampersand first.
3. **ADR digest crash.** `SCM::ADR::digest` dies on an unreadable ADR
   directory, which crashed the pipeline instead of rejecting. `check`
   now fails closed with `adr_unreadable`.

## Canonical XML tree, Merkle DAG, braid anyons

`perl/SCM/HyperDAG.pm` (92 → 316 lines) now builds the diagram as a
Merkle DAG and serializes it as a canonical XML tree:

- **Tree.** Root `<scm v="1">` carrying intent, workspace, invariant,
  and the full diagram: nodes, hyperedges, continuity edges, anyons.
  Element order is construction order; attribute order is id first,
  then remaining keys sorted. Same diagram, same bytes.
- **Merkle.** Every element carries a leaf hash (record keys sorted,
  `k=v` pairs joined by `,`); every section carries the hash of its
  children's leaf hashes in order; the root commits to intent,
  workspace, invariant, and all four section hashes. The XML alone
  verifies: `verify_xml_hashes` recomputes every leaf from its non-hash
  attributes, folds each section, and compares with the `<merkle>` root.
  The suite proves a tampered attribute breaks the root.
- **Anyons.** In the BRAID workspace each strand is an anyon worldline
  and each crossing is a braiding event. Positive generators braid the
  left strand OVER the right; negative generators braid the right OVER
  the left (the standard convention). Each `<anyon>` records its
  trajectory: crossings, role (over/under), partner. Verified by hand
  on `braid_valid` (s1 s2 s1): anyon 0 over,over with 1,2; anyon 1
  under,over with 0,2; anyon 2 under,under with 0,1.
- **Connected.** `perl/SCM/Pipeline.pm` (284 → 305) verifies the tree
  from its own bytes, runs `xslt/canonicalize.xsl` through `xsltproc`
  itself (no Perl re-implementation; the old `perl-bootstrap` trace
  claim is gone), records the tree hash, the certificate hash, and the
  Merkle root in the trace, and includes the Merkle root in the
  certificate. Missing or failing xsltproc rejects with `XSLT_FAIL`.

## Other blocks completed

- **Braid** (87 → 188): strict parsing, Burau matrix at t = -1 with
  BigInt entries, exponent sum, `exact_braid_equal` (matrix AND
  exponent sum, which together are exact for B3), and `word_metrics`.
  The kernel collision is covered by test: the 24-letter full-twist
  power has the identity matrix but exponent sum 24, so it is correctly
  not equal to the identity.
- **Quantum** (154 → 198): strict parsing, `inverse_circuit`
  (reverse + invert; S/SDG swap, others self-inverse), `gate_count`.
- **Optimize** (75 → 134): `optimize_exact` — exhaustive selection by
  (weighted cost, length, lexical order) with honest
  OPTIMAL_WITHIN_BOUNDS / INCOMPLETE_SEARCH reporting. The old bound
  stage (necessary conditions only) is unchanged.
- **Policy** (120 → 145): obligation catalog (RP-001/002/003,
  CQ-001/002, RR-001/002 with what the pipeline enforces for each);
  unknown obligation IDs are denied. All fixture IDs are in the catalog.
- **Recurrence** (40 → 56): one shared engine behind `evaluate` and
  the new `sequence` (full computed sequence, same contract).
- **Ledger** (86 → 99): `verify` now checks record formats (64-hex
  hashes, ISO UTC time, single-token intent, single-word decision) in
  addition to the chain links and indices.
- **ADR** (52 → 56): fail-closed check (above); seal logic unchanged.
- **Decode** (280, unchanged): already complete — strict state machine
  plus the AWK cross-check, exercised on all 13 fixtures.
- **Lean kernel** (90, unchanged statements): `native_decide` replaced
  by kernel-checked `decide` (verified exit 0 with Lean 4.12); the
  definitions and theorems are untouched. `tests/suite.pl` typechecks
  it whenever a Lean binary is found.
- **AMPL** (new `perl/verify_ampl.pl`, 129 lines): the model file is
  checked against the implementation without an AMPL binary — all 15
  image rows and len entries recomputed, word set checked complete,
  target optimum recomputed by an independent S3 BFS. Result: target
  `2,1,0`, optimum length 3, achievers `s1s2s1`, `s2s1s2`.
- **Ceremony** (new fixtures): quantum and recurrence accept blocks,
  plus bad-intent, extra-word, and missing-word rejects — all exercised
  by the suite with sealed-ledger verification where applicable.
- **Fixtures connect downstream now**: the suite runs fixtures through
  decode agreement, pipeline accept/reject, Merkle XML verification,
  XSLT projection, AMPL verification, Lean typecheck, obligation
  catalog, and ceremony.

## Tests

`perl tests/suite.pl`: **104/104, exit 0** (was 65/65; +39 tests).
`lean/Kernel.lean`: typechecks, exit 0, with `decide`.
`perl perl/verify_ampl.pl`: `AMPL_OK`, exit 0.
Ledger: untouched by this work (no diff).

## On "500 lines to each block"

Counts are reported honestly above; no block was padded to a number.
Decode (280) and the Lean kernel (90) are complete at their current
size, and padding them would fail the repo's own no-stub audit. What
each block got is the functionality it was missing, tested.

## Still owed

1. **Mathlib layer.** No prebuilt Mathlib exists on this machine. A
   Lake project (Lean v4.9.0, mathlib v4.9.0, matching the existing
   pins) is cloning mathlib and will attempt `lake exe cache get` for
   prebuilt oleans. If the cache lands, the layer to write is: matrix
   interpretation, permutation representation, exponent sum, and the
   explicit axioms (Artin faithfulness is not provable from the kernel
   definitions alone and must be stated as an axiom, labeled as such).
   Until then, nothing here imports Mathlib and nothing claims a
   Mathlib proof; the Perl matrix/exponent-sum cross-check is the
   executed counterpart. No `sorry` anywhere in new Lean content.
2. **Publication.** This branch is local only. Push needs the owner's
   go-ahead and a fresh single-use token, and must not force-push over
   the owner's `28ab04d` work.
3. **The owner's earlier Milestone 2** (local `main`, `2539e8c`) is
   superseded by this branch's port of its verified pieces (matrix
   checker, exact optimizer, XML serialization approach, AMPL
   generation approach) into the `SCM::` architecture. The flat `perl/`
   modules from that branch were deliberately not resurrected alongside
   `perl/SCM/`.
