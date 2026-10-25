# Lean kernel

`Kernel.lean` defines the Artin action and proves the braid relation and inverse cancellation with kernel-checked `decide` (previously `native_decide`; the statements are unchanged, the evidence is stronger because it no longer trusts native code evaluation). It typechecks with Lean 4.12 (`~/.elan/bin/lean` on the build machine; the toolchain is not on the default PATH). `tests/suite.pl` typechecks it whenever a Lean binary is found, and skips the check with a note when none is installed. The running proof remains the agreement of the Perl checker and `compcert/scm_rt.c`; the Lean kernel is the independent formal statement of the same action.

## Mathlib layer (pending)

The framework's axioms and the Mathlib development (matrix interpretation, permutation representation, exponent sum, and the explicit axiom for Artin faithfulness, which is not provable from the kernel's definitions alone) belong in a Lake project pinned to a toolchain with a prebuilt Mathlib cache. No prebuilt Mathlib exists on this machine yet; a cache download is in progress at the time of this writing. Until it lands, nothing here imports Mathlib and nothing claims a Mathlib proof: the kernel's `decide` proofs are the verified formal content, and the Perl matrix/exponent-sum cross-check (`SCM::Braid::exact_braid_equal`) is the executed counterpart of the matrix interpretation.
