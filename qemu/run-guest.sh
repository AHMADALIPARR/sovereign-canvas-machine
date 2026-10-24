#!/bin/sh
# Copyright (C) 2026 AHMAD ALI PARR
# Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
# Fail closed. This bootstrap does not launch QEMU.
# Unsafe arguments are rejected before the authorization denial so a
# caller cannot smuggle a net or tool device in behind a later flag.

set -eu
HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
CONF="$HERE/guest.conf"

for arg in "$@"; do
    case "$arg" in
        *hostfwd*|*smb*|*virtfs*|*tool*|*-net*|*-netdev*)
            echo "DENY:unsafe_qemu_arg"
            exit 2
            ;;
    esac
done

grep -q '^net=none$' "$CONF" || { echo "DENY:guest_net"; exit 2; }
grep -q '^tools=disabled$' "$CONF" || { echo "DENY:guest_tools"; exit 2; }
grep -q '^model_tools=0$' "$CONF" || { echo "DENY:guest_tools"; exit 2; }

echo "DENY:qemu_not_authorized"
exit 1
