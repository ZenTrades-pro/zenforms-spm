#!/bin/sh
set -eu
test_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test_binary=$(mktemp -t asset-token-tests)
trap 'rm -f "$test_binary"' EXIT
swiftc "$test_root/../../Sources/Extra/FPAssetTokens.swift" "$test_root/main.swift" -o "$test_binary"
"$test_binary" "$test_root"
