#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

BASE_URL="https://github.com/fairy-stockfish/Fairy-Stockfish/releases/download/fairy_sf_14"

curl --fail --location --remote-name "${BASE_URL}/fairy-stockfish_x86-64-bmi2"
curl --fail --location --remote-name "${BASE_URL}/fairy-stockfish_x86-64-bmi2.exe"
curl --fail --location --remote-name "${BASE_URL}/fairy-stockfish_x86-64-modern"
curl --fail --location --remote-name "${BASE_URL}/fairy-stockfish_x86-64-modern.exe"
curl --fail --location --remote-name "${BASE_URL}/fairy-stockfish_x86-64"
curl --fail --location --remote-name "${BASE_URL}/fairy-stockfish_x86-64.exe"
