# SCM-CANVAS/1.0

Line oriented. No leading or trailing spaces. Characters outside letters, digits, space, colon, underscore, dot, slash, and hyphen are rejected before any other rule. Maximum line length 512. Maximum record size 4096.

```
SCM-CANVAS/1.0
INTENT SCM-<token>
WORKSPACE BRAID | QUANTUM | RECURRENCE
STATUS UNVERIFIED
```

STATUS other than UNVERIFIED is rejected. The model cannot grade its own proposal.

## BRAID

```
TARGET <gen>+
CANDIDATE <gen>+
```

Generators: `s1`, `s2`, `s1_inv`, `s2_inv`. At most 12. COST equals the candidate length. TRANSFORMATIONS is 0 when the strings are identical and at least 1 otherwise. Obligations RP-001 and RP-002 are required, plus RP-003 when the strings differ.

Equality is the Artin action on F3. The underlying permutation is only a lower bound.

## QUANTUM

```
QUBITS <1-4>
TARGET <gate>+
CANDIDATE <gate>+
```

Gates: `H:q` `X:q` `Y:q` `Z:q` `S:q` `SDG:q` `CNOT:c:t` `CZ:c:t`. At most 32. COST equals the candidate length. Obligations CQ-001 and CQ-002. Equality is the Clifford tableau, up to global phase. T is not in the gate set.

## RECURRENCE

```
ORDER <1-6>
COEFFS <k integers in -20..20>
INITIAL <k integers>
TARGET_INDEX <0..30>
TARGET_VALUE <integer>
CANDIDATE_VALUE <integer>
```

`a_n = c0*a_{n-1} + ... + c_{k-1}*a_{n-k}`. COST equals the order. Obligations RR-001 and RR-002. The machine recomputes the value. An intermediate outside ±1e9 is rejected.

## Common tail

```
COST <positive integer <= 32>
TRANSFORMATIONS <0..32>
PROOF_OBLIGATIONS <XX-000>+
RESOURCE_ESTIMATE <cycles 1..100000> <memory 1..1048576>
END
```

Field order is fixed. Unknown lines, missing END, and duplicate fields are rejected.
