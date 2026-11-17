#!/bin/bash
# Installs the BlackHole drivers and waits until CoreAudio actually publishes them.
#
# The cask asks for a reboot; restarting coreaudiod is enough. Without this the
# integration suite silently skips and every job goes green while covering nothing,
# which is the failure mode this script exists to prevent. Shared by both workflows so
# they cannot drift apart.
set -euo pipefail

brew install --cask blackhole-2ch
brew install --cask blackhole-16ch
sudo killall coreaudiod || true

for attempt in $(seq 1 30); do
  devices=$(system_profiler SPAudioDataType 2>/dev/null || true)
  if echo "$devices" | grep -q "BlackHole 2ch" && echo "$devices" | grep -q "BlackHole 16ch"; then
    echo "Both BlackHole devices visible after ${attempt} attempt(s)."
    exit 0
  fi
  sleep 2
done

echo "::error::BlackHole 2ch and/or 16ch never became visible to CoreAudio."
system_profiler SPAudioDataType 2>/dev/null | grep -iE "^ +[A-Za-z].*:$" || true
exit 1
