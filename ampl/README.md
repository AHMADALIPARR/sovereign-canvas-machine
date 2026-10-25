# Permutation bound

`braid_perm.mod` is an AMPL model of the shortest adjacent-transposition word on S3. It is a necessary condition only: a pure braid can be nontrivial and still have trivial permutation. The supervisor does not call AMPL. The executed bound is the BFS in `perl/SCM/Optimize.pm`.

## Contract verification

AMPL itself is not available in this environment, so the model file cannot be solved here. What is verified, by `perl/verify_ampl.pl` (run by `tests/suite.pl`), is that the model file agrees with the executed implementation on every entry: every `image[]` row recomputed from `SCM::Braid::permutation`, every `len[]` entry recomputed from the word, the word set checked complete for positive words of length at most 3, and the model's target optimum recomputed by an independent S3 breadth-first search written in the verifier, not imported from `Optimize`. Current result: 15 words verified, target `2,1,0`, optimum length 3, achievers `s1s2s1`, `s2s1s2`. If the model file and the implementation ever disagree, the verifier exits 1 and the suite fails.
