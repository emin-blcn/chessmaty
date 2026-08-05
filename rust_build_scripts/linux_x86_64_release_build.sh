#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT/rust"

cargo build --release --target x86_64-unknown-linux-gnu

cd "$REPO_ROOT"

rm -f "$REPO_ROOT/godot/lib/librust_linux_x86_64_release.so"
cp "$REPO_ROOT/rust/target/x86_64-unknown-linux-gnu/release/librust.so" "$REPO_ROOT/godot/lib/librust_linux_x86_64_release.so"