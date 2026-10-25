#!/bin/sh
# Copyright (C) 2026 AHMAD ALI PARR
# Sovereign Canvas Machine (SCM-002). AGPL-3.0-only.
#
# Download Snapkitty/snapkitty-merged outside the trust boundary, verify
# SHA-256, place under models/, then optionally register via ingress.
#
#   ./models/fetch_snapkitty_merged.sh
#   ./models/fetch_snapkitty_merged.sh --register   # also call ingress register_gguf
#
# Source: https://huggingface.co/Snapkitty/snapkitty-merged
# File:   snapkitty-merged.Q4_K_M.gguf (~2.71 GiB)
# SHA256: 4d959da2985affc363c02784307ac135a69e77768d8d5475c6f15bb99560c59f

set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
MODELS="$ROOT/models"
NAME="snapkitty-merged.Q4_K_M.gguf"
DEST="$MODELS/$NAME"
EXPECTED_SHA="4d959da2985affc363c02784307ac135a69e77768d8d5475c6f15bb99560c59f"
HF_URL="https://huggingface.co/Snapkitty/snapkitty-merged/resolve/main/snapkitty-merged.Q4_K_M.gguf"
REGISTER=0

for arg in "$@"; do
    case "$arg" in
        --register) REGISTER=1 ;;
        --help|-h)
            echo "Usage: $0 [--register]"
            exit 0
            ;;
        *)
            echo "DENY:unknown_arg:$arg" >&2
            exit 2
            ;;
    esac
done

mkdir -p "$MODELS"

if [ -f "$DEST" ]; then
    echo "exists: $DEST"
else
    echo "downloading $HF_URL"
    echo "target:     $DEST"
    # curl only — no eval, no shell interpolation of remote content.
    curl -fL --retry 3 --retry-delay 2 -o "$DEST.partial" "$HF_URL"
    mv "$DEST.partial" "$DEST"
fi

echo "verifying SHA-256..."
GOT=$(sha256sum "$DEST" | awk '{print $1}')
if [ "$GOT" != "$EXPECTED_SHA" ]; then
    echo "DENY:GGUF:sha_mismatch got=$GOT expected=$EXPECTED_SHA" >&2
    rm -f "$DEST"
    exit 1
fi
echo "SHA-256 OK: $GOT"
chmod 0640 "$DEST"

if [ "$REGISTER" -eq 1 ]; then
    SOCK=${SCM_SOCK:-}
    if [ -z "$SOCK" ]; then
        if [ -S "$ROOT/run/scm.sock" ]; then
            SOCK="$ROOT/run/scm.sock"
        else
            SOCK="/tmp/scm-$(id -u).sock"
        fi
    fi
    if [ ! -S "$SOCK" ]; then
        echo "DENY:ingress_not_running (no socket at $SOCK)" >&2
        echo "start: php ingress/server.php" >&2
        exit 1
    fi
    php "$ROOT/ingress/client.php" --sock "$SOCK" --json \
        "{\"op\":\"register_gguf\",\"name\":\"$NAME\",\"source\":\"$DEST\"}"
fi

echo "ready: $DEST"
echo "generate: php ingress/client.php --json '{\"op\":\"generate\",\"model\":\"$NAME\"}'"
