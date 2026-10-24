# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

#!/usr/bin/awk -f
# Deterministic decoder for SCM-CANVAS/1.0.
# Independent of perl/SCM/Decode.pm. The supervisor accepts a record only
# when both decoders agree.

function badchar(s,    i, c) {
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c !~ /[A-Za-z0-9 :_.-]/ && c != "/") return 1
    }
    return 0
}

function fail(msg) {
    if (error == "") error = msg
}

function body_of(line,    sp) {
    sp = index(line, " ")
    if (sp == 0) return ""
    return substr(line, sp + 1)
}

function key_of(line,    sp) {
    sp = index(line, " ")
    if (sp == 0) return line
    return substr(line, 1, sp - 1)
}

function is_int(v, lo, hi,    n) {
    if (v !~ /^-?[0-9]+$/) return 0
    if (length(v) > 1 && (substr(v, 1, 1) == "0" || substr(v, 1, 2) == "-0")) return 0
    n = v + 0
    if (n < lo || n > hi) return 0
    return 1
}

function ints_ok(s, expect, lo, hi,    n, i, a) {
    n = split(s, a, " ")
    if (n != expect) return 0
    for (i = 1; i <= n; i++) {
        if (!is_int(a[i], lo, hi)) return 0
    }
    return 1
}

function gens_ok(s,    n, i, a, g) {
    n = split(s, a, " ")
    if (n < 1 || n > 12) return 0
    for (i = 1; i <= n; i++) {
        g = a[i]
        if (g != "s1" && g != "s2" && g != "s1_inv" && g != "s2_inv") return 0
    }
    return 1
}

function gates_ok(s, nq,    n, i, a, g, p, c, t, q, k) {
    n = split(s, a, " ")
    if (n < 1 || n > 32) return 0
    for (i = 1; i <= n; i++) {
        g = a[i]
        if (g ~ /^(SDG|H|X|Y|Z|S):[0-9]+$/) {
            k = index(g, ":")
            q = substr(g, k + 1) + 0
            if (q < 0 || q >= nq) return 0
        } else if (g ~ /^(CNOT|CZ):[0-9]+:[0-9]+$/) {
            split(g, p, ":")
            c = p[2] + 0
            t = p[3] + 0
            if (c == t || c < 0 || t < 0 || c >= nq || t >= nq) return 0
        } else {
            return 0
        }
    }
    return 1
}

BEGIN {
    error = ""
    state = "NEED_HEADER"
    ws = ""
    order = 0
    nq = 0
    size = 0
}

{
    if (error != "") next
    if (length($0) > 512) { fail("LINE_TOO_LONG"); next }
    if ($0 ~ /^ / || $0 ~ / $/ || $0 == "") { fail("BAD_WHITESPACE"); next }
    line = $0
    if (badchar(line)) { fail("METACHAR"); next }
    size += length(line) + 1
    if (size > 4096) { fail("RECORD_TOO_LARGE"); next }
    key = key_of(line)
    body = body_of(line)

    if (state == "NEED_HEADER") {
        if (line != "SCM-CANVAS/1.0") { fail("MISSING_HEADER"); next }
        print "protocol=SCM-CANVAS/1.0"
        state = "NEED_INTENT"
        next
    }
    if (state == "NEED_INTENT") {
        if (key != "INTENT") { fail("BAD_FIELD_ORDER"); next }
        if (body !~ /^SCM-[A-Z0-9]+(-[A-Z0-9]+)*$/ || length(body) > 64) {
            fail("BAD_INTENT"); next
        }
        print "intent=" body
        state = "NEED_WORKSPACE"
        next
    }
    if (state == "NEED_WORKSPACE") {
        if (key != "WORKSPACE") { fail("BAD_FIELD_ORDER"); next }
        if (body != "BRAID" && body != "QUANTUM" && body != "RECURRENCE") {
            fail("UNKNOWN_WORKSPACE"); next
        }
        print "workspace=" body
        ws = body
        state = "NEED_STATUS"
        next
    }
    if (state == "NEED_STATUS") {
        if (key != "STATUS") { fail("BAD_FIELD_ORDER"); next }
        if (body != "UNVERIFIED") { fail("BAD_STATUS"); next }
        print "status=UNVERIFIED"
        if (ws == "BRAID") state = "NEED_TARGET"
        else if (ws == "QUANTUM") state = "NEED_QUBITS"
        else state = "NEED_ORDER"
        next
    }
    if (state == "NEED_QUBITS") {
        if (key != "QUBITS") { fail("BAD_FIELD_ORDER"); next }
        if (body !~ /^[1-4]$/) { fail("BAD_QUBITS"); next }
        print "qubits=" body
        nq = body + 0
        state = "NEED_TARGET"
        next
    }
    if (state == "NEED_ORDER") {
        if (key != "ORDER") { fail("BAD_FIELD_ORDER"); next }
        if (body !~ /^[1-6]$/) { fail("BAD_ORDER"); next }
        print "order=" body
        order = body + 0
        state = "NEED_COEFFS"
        next
    }
    if (state == "NEED_COEFFS") {
        if (key != "COEFFS") { fail("BAD_FIELD_ORDER"); next }
        if (!ints_ok(body, order, -20, 20)) { fail("BAD_COEFFS"); next }
        print "coeffs=" body
        state = "NEED_INITIAL"
        next
    }
    if (state == "NEED_INITIAL") {
        if (key != "INITIAL") { fail("BAD_FIELD_ORDER"); next }
        if (!ints_ok(body, order, -1000000000, 1000000000)) { fail("BAD_INITIAL"); next }
        print "initial=" body
        state = "NEED_INDEX"
        next
    }
    if (state == "NEED_INDEX") {
        if (key != "TARGET_INDEX") { fail("BAD_FIELD_ORDER"); next }
        if (!is_int(body, 0, 30)) { fail("BAD_INDEX"); next }
        print "target_index=" body
        state = "NEED_TARGET_VALUE"
        next
    }
    if (state == "NEED_TARGET_VALUE") {
        if (key != "TARGET_VALUE") { fail("BAD_FIELD_ORDER"); next }
        if (!is_int(body, -1000000000, 1000000000)) { fail("BAD_TARGET_VALUE"); next }
        print "target_value=" body
        state = "NEED_CANDIDATE_VALUE"
        next
    }
    if (state == "NEED_CANDIDATE_VALUE") {
        if (key != "CANDIDATE_VALUE") { fail("BAD_FIELD_ORDER"); next }
        if (!is_int(body, -1000000000, 1000000000)) { fail("BAD_CANDIDATE_VALUE"); next }
        print "candidate_value=" body
        state = "NEED_COST"
        next
    }
    if (state == "NEED_TARGET") {
        if (key != "TARGET") { fail("BAD_FIELD_ORDER"); next }
        if (ws == "BRAID") {
            if (!gens_ok(body)) { fail("BAD_TARGET"); next }
        } else if (!gates_ok(body, nq)) { fail("BAD_TARGET"); next }
        print "target=" body
        state = "NEED_CANDIDATE"
        next
    }
    if (state == "NEED_CANDIDATE") {
        if (key != "CANDIDATE") { fail("BAD_FIELD_ORDER"); next }
        if (ws == "BRAID") {
            if (!gens_ok(body)) { fail("BAD_CANDIDATE"); next }
        } else if (!gates_ok(body, nq)) { fail("BAD_CANDIDATE"); next }
        print "candidate=" body
        state = "NEED_CANDIDATE"
        state = "NEED_COST"
        next
    }
    if (state == "NEED_COST") {
        if (key != "COST") { fail("BAD_FIELD_ORDER"); next }
        if (body !~ /^[1-9][0-9]*$/ || (body + 0) > 32) { fail("BAD_COST"); next }
        print "cost=" body
        state = "NEED_TRANSFORMATIONS"
        next
    }
    if (state == "NEED_TRANSFORMATIONS") {
        if (key != "TRANSFORMATIONS") { fail("BAD_FIELD_ORDER"); next }
        if (body !~ /^[0-9]+$/ || (body + 0) > 32) { fail("BAD_TRANSFORMATIONS"); next }
        if (length(body) > 1 && substr(body, 1, 1) == "0") { fail("BAD_TRANSFORMATIONS"); next }
        print "transformations=" body
        state = "NEED_OBLIGATIONS"
        next
    }
    if (state == "NEED_OBLIGATIONS") {
        if (key != "PROOF_OBLIGATIONS") { fail("BAD_FIELD_ORDER"); next }
        if (body !~ /^[A-Z][A-Z]-[0-9][0-9][0-9]( [A-Z][A-Z]-[0-9][0-9][0-9])*$/) {
            fail("BAD_OBLIGATIONS"); next
        }
        n = split(body, tmp, " ")
        if (n > 8) { fail("BAD_OBLIGATIONS"); next }
        print "proof_obligations=" body
        state = "NEED_RESOURCE"
        next
    }
    if (state == "NEED_RESOURCE") {
        if (key != "RESOURCE_ESTIMATE") { fail("BAD_FIELD_ORDER"); next }
        n = split(body, tmp, " ")
        if (n != 2) { fail("BAD_RESOURCE"); next }
        if (!is_int(tmp[1], 1, 100000) || !is_int(tmp[2], 1, 1048576)) {
            fail("BAD_RESOURCE"); next
        }
        print "cycles=" tmp[1]
        print "memory=" tmp[2]
        state = "NEED_END"
        next
    }
    if (state == "NEED_END") {
        if (line != "END") { fail("UNKNOWN_LINE"); next }
        print "decode=OK"
        state = "DONE"
        next
    }
    fail("UNKNOWN_LINE")
}

END {
    if (error != "") {
        print "ERROR:" error
        exit 1
    }
    if (state != "DONE") {
        print "ERROR:TRUNCATED"
        exit 1
    }
}
