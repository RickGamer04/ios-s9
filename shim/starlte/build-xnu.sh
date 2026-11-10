#!/bin/bash
# Galaxy S9 XNU loader + BOOT image.
#   build-xnu.sh STOCK_BOOT.img PAYLOAD.bin OUT.img
set -euo pipefail
cd "$(dirname "$0")"
CC=${CC:-$(command -v aarch64-elf-gcc || command -v aarch64-linux-gnu-gcc)}
OBJCOPY=${OBJCOPY:-${CC%gcc}objcopy}
NM=${NM:-${CC%gcc}nm}
CFLAGS="-O2 -ffreestanding -nostdlib -fno-pic -mgeneral-regs-only -mstrict-align -fno-stack-protector -fno-tree-loop-distribute-patterns -march=armv8-a -Wall -Wextra -Wno-unused-function -Wno-unused-variable -DDECON_TRIG_WRITE"
mkdir -p out
$CC $CFLAGS -c start.S -o out/xstart.o
$CC $CFLAGS -c loader_xnu.c -o out/xloader.o
$CC $CFLAGS -c ../fdt.c -o out/xfdt.o
$CC $CFLAGS -c ufs_probe.c -o out/xufs.o
$CC $CFLAGS -static -T loader.ld -Wl,--build-id=none -Wl,-N out/xstart.o out/xloader.o out/xfdt.o out/xufs.o -o out/xloader.elf
$OBJCOPY -O binary out/xloader.elf out/XImage
size=$($NM out/xloader.elf | awk '$3=="_end"{print "0x"$1}')
truncate -s $((size)) out/XImage
python3 -I ../../tools/dreamlte_mkboot.py "$(realpath "$1")" out/XImage "$(realpath "$2")" "$(realpath -m "$3")"
