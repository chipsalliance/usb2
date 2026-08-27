#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."

rm -rf nccoex/build/janus_bfm
rm -rf nccoex/build/janus_tb

mapfile -t MODEL_FILES < <(
  grep '^MODELS/.*\.sv$' TESTBENCH/tb.inpfiles |
  sed 's#^#TESTBENCH/#'
)

mapfile -t TOP_FILES < <(
  grep '^TOP/.*\.vhdl$' TESTBENCH/tb.inpfiles |
  sed 's#^#TESTBENCH/#'
)

xrun -64bit -compile -sv \
  -xmlibdirname nccoex/xcelium.d \
  -incdir TESTBENCH/DATA \
  -makelib nccoex/build/janus_bfm \
  "${MODEL_FILES[@]}" \
  -endlib \
  -messages \
  -logfile nccoex/logs/compile_models.log

xrun -64bit -compile -v93 \
  -xmlibdirname nccoex/xcelium.d \
  -reflib nccoex/build/usb_lib \
  -reflib nccoex/build/lib_usb_ip_3511 \
  -reflib nccoex/build/janus_bfm \
  -makelib nccoex/build/janus_tb \
  "${TOP_FILES[@]}" \
  -endlib \
  -messages \
  -logfile nccoex/logs/compile_top.log

echo "[OK] TESTBENCH compilation completed"
