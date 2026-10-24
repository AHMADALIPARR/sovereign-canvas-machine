# Permutation bound

`braid_perm.mod` is an AMPL model of the shortest adjacent-transposition word on S3. It is a necessary condition only: a pure braid can be nontrivial and still have trivial permutation. The supervisor does not call AMPL. The executed bound is the BFS in `perl/SCM/Optimize.pm`.
