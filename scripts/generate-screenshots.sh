#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${1:-/tmp/pairpods-screenshots}"
WEBSITE_DIR="${2:-$PROJECT_DIR/../www.pairpods_app/src/assets/images/demo}"

echo "Building ScreenshotGenerator..."
cd "$PROJECT_DIR/ScreenshotGenerator"
swift build -c release 2>&1 | tail -3

echo "Generating screenshots..."
.build/release/ScreenshotGenerator --output-dir "$OUTPUT_DIR"

if [ -d "$WEBSITE_DIR" ]; then
  cp "$OUTPUT_DIR"/step-*.png "$WEBSITE_DIR/"
  echo "Screenshots copied to $WEBSITE_DIR"
else
  echo "Website dir not found at $WEBSITE_DIR — screenshots saved to $OUTPUT_DIR"
fi
