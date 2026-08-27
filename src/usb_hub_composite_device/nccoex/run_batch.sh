#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."

mkdir -p nccoex/logs
rm -f nccoex/logs/run_batch.log

xrun -64bit -R \
  -xmlibdirname nccoex/xcelium.d \
  -messages \
  -logfile nccoex/logs/run_batch.log

grep -q 'JANUS smoke test PASS' nccoex/logs/run_batch.log

echo "[OK] JANUS smoke test PASS"
