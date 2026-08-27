#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."

rm -rf nccoex/build/usb_lib
rm -rf nccoex/build/lib_usb_ip_3511

mapfile -t USB_FILES < <(
  sed -n \
    '1,/^RTL\/usb_app_hw_hub\.m\.vhdl$/p' \
    RTL/rtl.inpfiles |
  sed '/^[[:space:]]*$/d' |
  sed 's#^#RTL/#'
)

mapfile -t COMPOUND_FILES < <(
  sed -n \
    '/^INTERFACE\/ip_xxx_3511_hs_mem_compound\.e\.vhdl$/,$p' \
    RTL/rtl.inpfiles |
  sed '/^[[:space:]]*$/d' |
  sed 's#^#RTL/#'
)

xrun -64bit -compile -v93 \
  -xmlibdirname nccoex/xcelium.d \
  -makelib nccoex/build/usb_lib \
  "${USB_FILES[@]}" \
  -endlib \
  -makelib nccoex/build/lib_usb_ip_3511 \
  "${COMPOUND_FILES[@]}" \
  -endlib \
  -messages \
  -logfile nccoex/logs/compile_rtl.log

echo "[OK] RTL compilation completed"
