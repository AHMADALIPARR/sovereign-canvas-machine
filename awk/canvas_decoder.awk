# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

#!/usr/bin/awk -f
# canvas_decoder.awk — Deterministic decoder for Sovereign Canvas protocol
# Input: line-oriented Canvas record on stdin
# Output: key=value pairs or ERROR: message

BEGIN {
    FS = " "
    max_line = 512
    max_record = 4096
    record_size = 0
    state = "HEADER"
    error = ""
}

{
    if (length($0) > max_line) {
        error = "LINE_TOO_LONG"
        next
    }
    record_size += length($0) + 1
    if (record_size > max_record) {
        error = "RECORD_TOO_LARGE"
        next
    }
}

/^SCM-CANVAS\/1\.0$/ {
    if (state != "HEADER") { error = "UNEXPECTED_HEADER"; next }
    print "protocol=SCM-CANVAS/1.0"
    state = "FIELDS"
    next
}

/^INTENT / {
    if (state != "FIELDS") { error = "BAD_STATE"; next }
    print "intent=" $2
    next
}

/^WORKSPACE / {
    if (state != "FIELDS") { error = "BAD_STATE"; next }
    ws = $2
    if (ws != "BRAID" && ws != "QUANTUM" && ws != "RECURRENCE") {
        error = "UNKNOWN_WORKSPACE"
        next
    }
    print "workspace=" ws
    next
}

/^STATUS / {
    if (state != "FIELDS") { error = "BAD_STATE"; next }
    if ($2 != "UNVERIFIED") {
        error = "STATUS_NOT_UNVERIFIED"
        next
    }
    print "status=UNVERIFIED"
    next
}

/^TARGET / {
    print "target=" substr($0, 8)
    next
}

/^CANDIDATE / {
    print "candidate=" substr($0, 11)
    next
}

/^COST / {
    print "cost=" $2
    next
}

/^END$/ {
    if (error == "") {
        print "decode=OK"
    }
    exit
}

END {
    if (error != "") {
        print "ERROR:" error
        exit 1
    }
}
