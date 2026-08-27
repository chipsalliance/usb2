#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

./compile_rtl.sh
./compile_tb.sh
./elaborate.sh
./run_batch.sh

echo "[OK] Release 04 clean build and regression completed"
