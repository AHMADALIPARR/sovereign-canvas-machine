/-
Copyright (C) 2026 AHMAD ALI PARR
Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.

Artin action of B3 on F3. Two words are the same braid when the freely
reduced images of t1, t2, t3 agree. This file is the Lean obligation.
It is not typechecked in the bootstrap environment (no Lean binary).
The running decision is Perl and the independent C runtime.
-/

namespace SCM

inductive Gen where
  | s1 | s1i | s2 | s2i
  deriving DecidableEq, Repr, BEq

inductive F where
  | t1 | t2 | t3
  deriving DecidableEq, Repr, BEq

inductive Signed where
  | pos | neg
  deriving DecidableEq, Repr, BEq

structure Let where
  s : Signed
  f : F
  deriving DecidableEq, Repr, BEq

abbrev FWord := List Let
abbrev BWord := List Gen

def neg : Signed → Signed
  | .pos => .neg
  | .neg => .pos

def invW (w : FWord) : FWord :=
  (w.reverse.map fun l => {s := neg l.s, f := l.f})

def push (st : FWord) (l : Let) : FWord :=
  match st with
  | [] => [l]
  | top :: rest =>
    if top.f == l.f && top.s != l.s then rest else l :: st

def freduce (w : FWord) : FWord :=
  (w.foldl push []).reverse

def act : Gen → F → FWord
  | .s1,  .t1 => [{s := .pos, f := .t1}, {s := .pos, f := .t2}, {s := .neg, f := .t1}]
  | .s1,  .t2 => [{s := .pos, f := .t1}]
  | .s1,  .t3 => [{s := .pos, f := .t3}]
  | .s1i, .t1 => [{s := .pos, f := .t2}]
  | .s1i, .t2 => [{s := .neg, f := .t2}, {s := .pos, f := .t1}, {s := .pos, f := .t2}]
  | .s1i, .t3 => [{s := .pos, f := .t3}]
  | .s2,  .t1 => [{s := .pos, f := .t1}]
  | .s2,  .t2 => [{s := .pos, f := .t2}, {s := .pos, f := .t3}, {s := .neg, f := .t2}]
  | .s2,  .t3 => [{s := .pos, f := .t2}]
  | .s2i, .t1 => [{s := .pos, f := .t1}]
  | .s2i, .t2 => [{s := .pos, f := .t3}]
  | .s2i, .t3 => [{s := .neg, f := .t3}, {s := .pos, f := .t2}, {s := .pos, f := .t3}]

def subst (w : FWord) (img : F → FWord) : FWord :=
  freduce (w.foldl (fun acc l =>
    let piece := img l.f
    acc ++ match l.s with
      | .pos => piece
      | .neg => invW piece) [])

def ident : F → FWord
  | f => [{s := .pos, f := f}]

def applyGen (img : F → FWord) (g : Gen) : F → FWord :=
  fun f => subst (img f) (act g)

def artin (w : BWord) : F → FWord :=
  w.foldl applyGen ident

def invariant (w : BWord) : FWord × FWord × FWord :=
  (artin w .t1, artin w .t2, artin w .t3)

theorem braid_relation :
    invariant [.s1, .s2, .s1] = invariant [.s2, .s1, .s2] := by
  decide

theorem inverse_cancels :
    invariant [.s1, .s1i] = invariant [.s2, .s2i] := by
  decide

end SCM
