/* Copyright (C) 2026 AHMAD ALI PARR
 * Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
 * CompCert-subset runtime. No VLAs, no setjmp, no libc beyond snprintf.
 * Bootstrap compiler is gcc -std=c99. This is not a CompCert proof.
 */
#ifndef SCM_RT_H
#define SCM_RT_H

#include <stddef.h>
#include <stdint.h>

typedef struct ScmGate {
    int op; /* 1 H, 2 X, 3 Y, 4 Z, 5 S, 6 SDG, 7 CNOT, 8 CZ */
    int a;
    int b;
} ScmGate;

int scm_braid_invariant(const int *word, int n, char *out, int cap);
int scm_quantum_invariant(int nq, const ScmGate *gates, int ng, char *out, int cap);
int scm_recurrence_invariant(int order, const int64_t *coeff, const int64_t *initial,
                              int index, char *out, int cap);

#endif
