#!/bin/bash
# Kernel Mach-O -> Galaxy S9 BOOT image.
#   make-boot.sh KERNEL STOCK_BOOT.img OUT.img [boot-args...]
set -euo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
kernel=$(realpath "$1"); stock=$(realpath "$2"); out=$(realpath -m "$3")
shift 3
args=${*:-debug=0xc serial=3 cpus=1 keepsyms=1 -enable_kprintf_spam -noprogress wdt=-1 wdt_test=no_user_checkin a5touchprobe=0 sweetfb_native=1}
work=$repo/shim/starlte/out
mkdir -p "$work"
python3 "$repo/tools/mkadt_starlte.py" "$work/starlte.adt" --canvas 1440x2960
python3 "$repo/tools/mkpayload.py" "$kernel" "$work/starlte.adt" "$work/payload.bin" --cmdline "$args"
bash "$repo/shim/starlte/build-xnu.sh" "$stock" "$work/payload.bin" "$out"
python3 -I "$repo/tools/dreamlte_bootimg_info.py" "$out" | head -4
