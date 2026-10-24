# Copyright (C) 2026 AHMAD ALI PARR
# Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
#
# Shortest positive word on the adjacent transpositions of S3.
# This is a necessary-condition bound, not a braid-equivalence oracle
# (the pure braid s1^2 is a nontrivial braid with trivial permutation).
# No AMPL binary is required to run the machine: perl/SCM/Optimize.pm
# searches the same Cayley graph and is what the supervisor calls.

set N := {0, 1, 2};
set W;
param len {W} >= 0;
param image {W, N} symbolic in N;
param target {N} symbolic in N;

var pick {W} binary;

minimize crossings: sum {w in W} len[w] * pick[w];

subject to one_word: sum {w in W} pick[w] = 1;

subject to hit {i in N}:
    sum {w in W: image[w,i] == target[i]} pick[w] = 1;

data;

set W := e s1 s2 s1s1 s1s2 s2s1 s2s2
          s1s1s1 s1s1s2 s1s2s1 s1s2s2
          s2s1s1 s2s1s2 s2s2s1 s2s2s2;

param len :=
    e 0
    s1 1  s2 1
    s1s1 2  s1s2 2  s2s1 2  s2s2 2
    s1s1s1 3  s1s1s2 3  s1s2s1 3  s1s2s2 3
    s2s1s1 3  s2s1s2 3  s2s2s1 3  s2s2s2 3;

# image[w, position] = strand sitting there. Identity is 0 1 2.
# Computed by the same adjacent-transposition action as SCM::Braid::permutation.
param image:
        0  1  2 :=
    e       0  1  2
    s1      1  0  2
    s2      0  2  1
    s1s1    0  1  2
    s1s2    1  2  0
    s2s1    2  0  1
    s2s2    0  1  2
    s1s1s1  1  0  2
    s1s1s2  0  2  1
    s1s2s1  2  1  0
    s1s2s2  1  0  2
    s2s1s1  0  2  1
    s2s1s2  2  1  0
    s2s2s1  1  0  2
    s2s2s2  0  2  1;

param target := 0 2  1 1  2 0;
