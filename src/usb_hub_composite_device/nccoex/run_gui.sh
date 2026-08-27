#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

mkdir -p logs
rm -f logs/run_gui.log

xrun -64bit -R \
  -xmlibdirname xcelium.d \
  -gui \
  -input gui_init.tcl \
  -messages \
  -logfile logs/run_gui.log
