#!/bin/bash
# Legion Y9000P IAX10H (83F5) audio check
# Usage: bash tools/check-audio.sh
set -u

echo "== macOS =="
sw_vers
echo "kernel: $(uname -r)"
echo

echo "== loaded audio/input kexts =="
kmutil showloaded 2>/dev/null | grep -Ei 'AppleALC|VoodooI2C|AW88399|Lilu|VoodooInput' || echo "(none)"
echo

echo "== SPKR nubs (expect 0x34 and 0x35) =="
ioreg -l -w0 -r -c VoodooI2CDeviceNub 2>/dev/null \
  | grep -E '"name" = <"SPKR|"i2cAddress"|"i2cResourceCount"' | sort -u
echo

echo "== AW88399 state =="
ioreg -l -w0 -r -c AW88399Driver 2>/dev/null \
  | grep -E 'AW88399(Ready|I2CAddress|PlaybackActive|AmplifierRunning|LastError|AudioEngine)' | sort -u
echo

echo "== ALC287 shared-DAC state =="
ioreg -l -w0 2>/dev/null | grep -E 'ALC287SharedDAC' | sort -u
echo

echo "== HDEF layout =="
ioreg -l -w0 -r -n HDEF 2>/dev/null | grep -E 'layout-id|alc-layout-id'
echo

echo "== boot-args =="
nvram boot-args 2>/dev/null || true
echo

echo "== kernel log (last 10m) =="
log show --last 10m --style compact 2>/dev/null \
  | grep -iE 'AW88399|AWDZ8399|ALC287Shared|Bound to HDA' | tail -40
echo

echo "== audio devices =="
system_profiler SPAudioDataType 2>/dev/null | sed -n '1,80p'
echo

echo "提示：播放音乐时再跑一次，确认 AW88399AmplifierRunning = Yes。"
