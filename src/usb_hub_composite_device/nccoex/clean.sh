#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

rm -rf build
rm -rf xcelium.d
rm -rf waves.shm
rm -rf .simvision
rm -rf INCA_libs
rm -rf xcelium_libs
rm -f xrun.log
rm -f xrun.history
rm -f xrun.key
rm -f .symbolnamelist
rm -f .symbolportinfomap
rm -rf logs

mkdir -p build
mkdir -p logs

echo "[OK] generated simulation files removed"
