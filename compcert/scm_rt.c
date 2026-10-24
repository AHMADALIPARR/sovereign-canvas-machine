/* Copyright (C) 2026 AHMAD ALI PARR
 * Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
 * Independent recomputation of braid, Clifford, and recurrence invariants.
 */
#include "scm_rt.h"

#include <stdio.h>
#include <string.h>

#define SCM_MAXF 4096
#define SCM_BOUND 1000000000LL

static int freduce(const int *in, int n, int *out) {
    int sp = 0;
    int i;
    for (i = 0; i < n; i++) {
        if (sp > 0 && out[sp - 1] == -in[i]) {
            sp--;
        } else {
            if (sp >= SCM_MAXF) {
                return -1;
            }
            out[sp++] = in[i];
        }
    }
    return sp;
}

/* Image of free generator f (1..3) under braid generator g (+-1, +-2). */
static int act(int g, int f, int *dst) {
    if (g == 1 && f == 1) { dst[0] = 1; dst[1] = 2; dst[2] = -1; return 3; }
    if (g == 1 && f == 2) { dst[0] = 1; return 1; }
    if (g == 1 && f == 3) { dst[0] = 3; return 1; }
    if (g == -1 && f == 1) { dst[0] = 2; return 1; }
    if (g == -1 && f == 2) { dst[0] = -2; dst[1] = 1; dst[2] = 2; return 3; }
    if (g == -1 && f == 3) { dst[0] = 3; return 1; }
    if (g == 2 && f == 1) { dst[0] = 1; return 1; }
    if (g == 2 && f == 2) { dst[0] = 2; dst[1] = 3; dst[2] = -2; return 3; }
    if (g == 2 && f == 3) { dst[0] = 2; return 1; }
    if (g == -2 && f == 1) { dst[0] = 1; return 1; }
    if (g == -2 && f == 2) { dst[0] = 3; return 1; }
    if (g == -2 && f == 3) { dst[0] = -3; dst[1] = 2; dst[2] = 3; return 3; }
    return -1;
}

int scm_braid_invariant(const int *word, int n, char *out, int cap) {
    int img[3][SCM_MAXF];
    int len[3];
    int k, s, i;
    if (n < 1 || n > 12 || cap < 8) {
        return -1;
    }
    len[0] = len[1] = len[2] = 1;
    img[0][0] = 1;
    img[1][0] = 2;
    img[2][0] = 3;
    for (k = 0; k < n; k++) {
        int next[3][SCM_MAXF];
        int nlen[3];
        int g = word[k];
        for (s = 0; s < 3; s++) {
            int buf[SCM_MAXF];
            int bn = 0;
            for (i = 0; i < len[s]; i++) {
                int L = img[s][i];
                int piece[4];
                int pn = act(g, L > 0 ? L : -L, piece);
                int j;
                if (pn < 0) {
                    return -1;
                }
                if (L > 0) {
                    for (j = 0; j < pn; j++) {
                        if (bn >= SCM_MAXF) return -1;
                        buf[bn++] = piece[j];
                    }
                } else {
                    for (j = pn - 1; j >= 0; j--) {
                        if (bn >= SCM_MAXF) return -1;
                        buf[bn++] = -piece[j];
                    }
                }
            }
            nlen[s] = freduce(buf, bn, next[s]);
            if (nlen[s] < 0) {
                return -1;
            }
        }
        for (s = 0; s < 3; s++) {
            len[s] = nlen[s];
            for (i = 0; i < nlen[s]; i++) {
                img[s][i] = next[s][i];
            }
        }
    }
    {
        int used = 0;
        out[0] = 0;
        for (s = 0; s < 3; s++) {
            if (s) {
                if (used + 1 >= cap) return -1;
                out[used++] = ';';
                out[used] = 0;
            }
            for (i = 0; i < len[s]; i++) {
                char tmp[32];
                int m = snprintf(tmp, sizeof tmp, "%s%d", i ? "," : "", img[s][i]);
                if (m < 0 || used + m >= cap) return -1;
                memcpy(out + used, tmp, (size_t)m);
                used += m;
                out[used] = 0;
            }
        }
    }
    return 0;
}

typedef struct Pauli {
    int n;
    uint32_t x;
    uint32_t z;
    int p;
} Pauli;

static Pauli pmul(Pauli a, Pauli b) {
    int ph = (a.p + b.p) % 4;
    int i;
    Pauli r;
    for (i = 0; i < a.n; i++) {
        int z1 = (int)((a.z >> i) & 1u);
        int x2 = (int)((b.x >> i) & 1u);
        ph = (ph + 2 * z1 * x2) % 4;
    }
    r.n = a.n;
    r.x = a.x ^ b.x;
    r.z = a.z ^ b.z;
    r.p = ph;
    return r;
}

static Pauli xop(int n, int q) {
    Pauli r;
    r.n = n;
    r.x = 1u << q;
    r.z = 0;
    r.p = 0;
    return r;
}

static Pauli zop(int n, int q) {
    Pauli r;
    r.n = n;
    r.x = 0;
    r.z = 1u << q;
    r.p = 0;
    return r;
}

static void gate_images(int n, ScmGate g, Pauli *X, Pauli *Z) {
    int i;
    for (i = 0; i < n; i++) {
        X[i] = xop(n, i);
        Z[i] = zop(n, i);
    }
    if (g.op == 1) { /* H */
        Pauli t = X[g.a];
        X[g.a] = Z[g.a];
        Z[g.a] = t;
    } else if (g.op == 5) { /* S: X -> i X Z */
        Pauli y = pmul(xop(n, g.a), zop(n, g.a));
        y.p = (y.p + 1) % 4;
        X[g.a] = y;
    } else if (g.op == 6) { /* SDG */
        Pauli y = pmul(xop(n, g.a), zop(n, g.a));
        y.p = (y.p + 3) % 4;
        X[g.a] = y;
    } else if (g.op == 2) { /* X */
        Z[g.a].p = (Z[g.a].p + 2) % 4;
    } else if (g.op == 4) { /* Z */
        X[g.a].p = (X[g.a].p + 2) % 4;
    } else if (g.op == 3) { /* Y */
        X[g.a].p = (X[g.a].p + 2) % 4;
        Z[g.a].p = (Z[g.a].p + 2) % 4;
    } else if (g.op == 7) { /* CNOT */
        X[g.a] = pmul(xop(n, g.a), xop(n, g.b));
        Z[g.b] = pmul(zop(n, g.a), zop(n, g.b));
    } else if (g.op == 8) { /* CZ */
        X[g.a] = pmul(xop(n, g.a), zop(n, g.b));
        X[g.b] = pmul(zop(n, g.a), xop(n, g.b));
    }
}

static Pauli conjugate(Pauli p, const Pauli *X, const Pauli *Z) {
    Pauli acc;
    int i;
    acc.n = p.n;
    acc.x = 0;
    acc.z = 0;
    acc.p = p.p;
    for (i = 0; i < p.n; i++) {
        if ((p.x >> i) & 1u) acc = pmul(acc, X[i]);
        if ((p.z >> i) & 1u) acc = pmul(acc, Z[i]);
    }
    return acc;
}

int scm_quantum_invariant(int nq, const ScmGate *gates, int ng, char *out, int cap) {
    Pauli curX[4], curZ[4];
    int i, k, used = 0;
    if (nq < 1 || nq > 4 || ng < 1 || ng > 32 || cap < 16) return -1;
    for (i = 0; i < nq; i++) {
        curX[i] = xop(nq, i);
        curZ[i] = zop(nq, i);
    }
    for (k = 0; k < ng; k++) {
        Pauli Xs[4], Zs[4], nX[4], nZ[4];
        gate_images(nq, gates[k], Xs, Zs);
        for (i = 0; i < nq; i++) {
            nX[i] = conjugate(curX[i], Xs, Zs);
            nZ[i] = conjugate(curZ[i], Xs, Zs);
        }
        for (i = 0; i < nq; i++) {
            curX[i] = nX[i];
            curZ[i] = nZ[i];
        }
    }
    out[0] = 0;
    for (i = 0; i < nq; i++) {
        char tmp[64];
        int m = snprintf(tmp, sizeof tmp, "%sX%d:%u,%u,%d|Z%d:%u,%u,%d",
                         i ? "|" : "", i, curX[i].x, curX[i].z, curX[i].p,
                         i, curZ[i].x, curZ[i].z, curZ[i].p);
        if (m < 0 || used + m >= cap) return -1;
        memcpy(out + used, tmp, (size_t)m);
        used += m;
        out[used] = 0;
    }
    return 0;
}

int scm_recurrence_invariant(int order, const int64_t *coeff, const int64_t *initial,
                              int index, char *out, int cap) {
    int64_t a[40];
    int n, j;
    if (order < 1 || order > 6 || index < 0 || index > 30 || cap < 16) return -1;
    for (j = 0; j < order; j++) {
        if (initial[j] > SCM_BOUND || initial[j] < -SCM_BOUND) return -1;
        a[j] = initial[j];
    }
    if (index < order) {
        if (snprintf(out, (size_t)cap, "value=%lld", (long long)a[index]) < 0) return -1;
        return 0;
    }
    for (n = order; n <= index; n++) {
        int64_t s = 0;
        for (j = 0; j < order; j++) {
            int64_t term = coeff[j] * a[n - 1 - j];
            if (term > 0 && s > SCM_BOUND - term) return -1;
            if (term < 0 && s < -SCM_BOUND - term) return -1;
            s += term;
            if (s > SCM_BOUND || s < -SCM_BOUND) return -1;
        }
        a[n] = s;
    }
    if (snprintf(out, (size_t)cap, "value=%lld", (long long)a[index]) < 0) return -1;
    return 0;
}
