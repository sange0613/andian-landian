#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-run}"
APP="$ROOT/dist/暗淡蓝点-Mac-轻量版-1.2.6/暗淡蓝点轻量版.app"
case "$MODE" in
  run|--debug|--logs|--telemetry|--verify) ;;
  *) printf 'usage: %s [--debug|--logs|--telemetry|--verify]\n' "$0" >&2; exit 2 ;;
esac

# Only restart this native target; leave the older Electron app untouched.
pkill -x DimBlueDotMac >/dev/null 2>&1 || true
bash "$ROOT/native-mac/build.sh"
if [ "$MODE" = --debug ]; then
  /usr/bin/open -n "$APP"
  sleep 1
  exec lldb -n DimBlueDotMac
fi
/usr/bin/open -n "$APP"
case "$MODE" in
  --verify)
    sleep 2
    pgrep -x DimBlueDotMac >/dev/null
    printf 'PASS: native Mac app launched\n'
    ;;
  --logs|--telemetry)
    exec /usr/bin/log stream --info --style compact --predicate 'process == "DimBlueDotMac"'
    ;;
esac
