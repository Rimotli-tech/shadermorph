#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/core_shaders/transitions"
DST_DIR="$ROOT_DIR/platforms/shadermorph_flutter/assets/shaders/core"

mkdir -p "$DST_DIR"

shopt -s nullglob
for shader in "$SRC_DIR"/morph_*.frag; do
  cp "$shader" "$DST_DIR"/
done

count=$(ls -1 "$DST_DIR"/morph_*.frag 2>/dev/null | wc -l | tr -d ' ')
echo "Synced $count morph shader(s) to $DST_DIR"