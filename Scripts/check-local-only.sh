#!/bin/sh
set -eu

forbidden='import[[:space:]]+(Network|FoundationNetworking)|URLSession|NW(Connection|PathMonitor|Browser)|https?://'

if grep -ERn --include='*.swift' "$forbidden" Sources; then
    echo "error: runtime networking is forbidden in LocalFaceKit sources" >&2
    exit 1
fi

echo "Local-only source check passed."
