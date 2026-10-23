#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BINARY="$PROJECT_DIR/build/FrameScript.app/Contents/MacOS/FrameScript"
SCREENSHOT_DIR="$PROJECT_DIR/build/screenshots"

if [ ! -x "$APP_BINARY" ]; then
  echo "Built FrameScript app executable was not found: $APP_BINARY" >&2
  exit 1
fi

mkdir -p "$SCREENSHOT_DIR"
for mode in $(seq 1 10); do
  screenshot=$(printf '%s/FrameScript-%02d.png' "$SCREENSHOT_DIR" "$mode")
  FRAMESCRIPT_SCREENSHOT_MODE="$mode" "$APP_BINARY" >/dev/null 2>&1 &
  app_pid=$!

  sleep 5
  if ! kill -0 "$app_pid" 2>/dev/null; then
    echo "FrameScript exited before screenshot $mode could be captured." >&2
    wait "$app_pid" || true
    exit 1
  fi

  screencapture -x "$screenshot"
  kill "$app_pid" 2>/dev/null || true
  wait "$app_pid" 2>/dev/null || true
  test -s "$screenshot"
  echo "Captured $screenshot"
done

count=$(find "$SCREENSHOT_DIR" -maxdepth 1 -name 'FrameScript-*.png' | wc -l | tr -d ' ')
if [ "$count" -ne 10 ]; then
  echo "Expected 10 screenshots, found $count." >&2
  exit 1
fi
