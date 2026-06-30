#!/usr/bin/env bash
# get.sh — one-command install for Signature Harness Kit
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/oanhduong/build-anything/master/get.sh)
set -euo pipefail

REPO="https://github.com/oanhduong/build-anything.git"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Fetching Signature Harness Kit..."
git clone --depth=1 "$REPO" "$TMPDIR" --quiet

bash "$TMPDIR/install.sh"
