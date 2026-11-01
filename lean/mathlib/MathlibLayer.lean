/-
Copyright (C) 2026 AHMAD ALI PARR
Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.

Mathlib layer wiring proof. This file establishes that the Lake project
in this directory resolves its pinned Mathlib v4.9.0 dependency and that
Mathlib-dependent proofs compile in this tree. The framework development
(matrix interpretation, permutation representation, exponent sum) is not
in this file.
-/

import Mathlib

example (a b : ℝ) : (a + b) ^ 2 = a ^ 2 + 2 * a * b + b ^ 2 := by ring

example (n : ℕ) : ∑ i ∈ Finset.range n, (2 * i + 1) = n ^ 2 := by
  induction n with
  | zero => simp
  | succ k ih => rw [Finset.sum_range_succ, ih]; ring
