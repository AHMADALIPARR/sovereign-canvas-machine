/* Copyright (C) 2026 AHMAD ALI PARR
 * Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
 * Fixed identities the runtime must reproduce without Perl.
 */
#include "scm_rt.h"

#include <stdio.h>
#include <string.h>

int main(void) {
    int rel_a[] = {1, 2, 1};
    int rel_b[] = {2, 1, 2};
    int bad[] = {1, 1, 2};
    int inv[] = {1, -1};
    char a[1024], b[1024], c[1024];
    ScmGate hzh[3];
    ScmGate xg[1];
    ScmGate cnot[2];
    int64_t coeff[2];
    int64_t init[2];
    char rec[64];

    if (scm_braid_invariant(rel_a, 3, a, 1024) != 0) return 1;
    if (scm_braid_invariant(rel_b, 3, b, 1024) != 0) return 1;
    if (scm_braid_invariant(bad, 3, c, 1024) != 0) return 1;
    if (strcmp(a, b) != 0) {
        fprintf(stderr, "relation failed %s vs %s\n", a, b);
        return 1;
    }
    if (strcmp(a, c) == 0) return 1;
    if (scm_braid_invariant(inv, 2, a, 1024) != 0) return 1;
    if (strcmp(a, "1;2;3") != 0) {
        fprintf(stderr, "inverse got %s\n", a);
        return 1;
    }

    hzh[0].op = 1; hzh[0].a = 0; hzh[0].b = 0;
    hzh[1].op = 4; hzh[1].a = 0; hzh[1].b = 0;
    hzh[2].op = 1; hzh[2].a = 0; hzh[2].b = 0;
    xg[0].op = 2; xg[0].a = 0; xg[0].b = 0;
    if (scm_quantum_invariant(1, hzh, 3, a, 1024) != 0) return 1;
    if (scm_quantum_invariant(1, xg, 1, b, 1024) != 0) return 1;
    if (strcmp(a, b) != 0) {
        fprintf(stderr, "hzh %s vs x %s\n", a, b);
        return 1;
    }

    cnot[0].op = 7; cnot[0].a = 0; cnot[0].b = 1;
    cnot[1] = cnot[0];
    if (scm_quantum_invariant(2, cnot, 2, a, 1024) != 0) return 1;

    coeff[0] = 1;
    coeff[1] = 1;
    init[0] = 0;
    init[1] = 1;
    if (scm_recurrence_invariant(2, coeff, init, 10, rec, 64) != 0) return 1;
    if (strcmp(rec, "value=55") != 0) {
        fprintf(stderr, "fib %s\n", rec);
        return 1;
    }
    printf("SELFTEST_OK %s\n", b);
    return 0;
}
