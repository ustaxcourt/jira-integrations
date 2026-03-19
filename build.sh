#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$REPO_ROOT/dist"
STAGE_DIR="$DIST_DIR/package"
ZIP_FILE="$DIST_DIR/lambda.zip"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

cp "$REPO_ROOT/src/handler.py" "$REPO_ROOT/src/adf.py" "$STAGE_DIR/"
cp -r "$REPO_ROOT/definitions" "$STAGE_DIR/"

(cd "$STAGE_DIR" && zip -r "$ZIP_FILE" .)

rm -rf "$STAGE_DIR"
echo "Built $ZIP_FILE"
