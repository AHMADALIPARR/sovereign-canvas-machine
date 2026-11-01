import Lake
open Lake DSL

package scmMathlib where

@[default_target]
lean_lib MathlibLayer where

require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "v4.9.0"
