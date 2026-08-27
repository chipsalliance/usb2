#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."

rm -rf nccoex/xcelium.d

xrun -64bit -elaborate -v93 \
  -xmlibdirname nccoex/xcelium.d \
  -reflib nccoex/build/usb_lib \
  -reflib nccoex/build/lib_usb_ip_3511 \
  -reflib nccoex/build/janus_bfm \
  -reflib nccoex/build/janus_tb \
  -work janus_tb \
  -top janus_compound_smoke_tb \
  -access +rwc \
  -messages \
  -logfile nccoex/logs/elaborate.log

echo "[OK] TESTBENCH elaboration completed"
