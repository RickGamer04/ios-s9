#!/bin/bash
# Galaxy S9 stage-0 loader. Usage: build.sh STOCK_BOOT.img
# Produces out/stage0-A.img (no DECON write) and out/stage0-B.img (DECON write).
set -euo pipefail
cd "$(dirname "$0")"
CC=${CC:-$(command -v aarch64-elf-gcc || command -v aarch64-linux-gnu-gcc)}
OBJCOPY=${OBJCOPY:-${CC%gcc}objcopy}
NM=${NM:-${CC%gcc}nm}
stock=$(realpath "$1")
CFLAGS="-O2 -ffreestanding -nostdlib -fno-pic -mgeneral-regs-only -mstrict-align -fno-stack-protector -fno-tree-loop-distribute-patterns -march=armv8-a -Wall -Wextra"
mkdir -p out
head -c 4096 /dev/zero > out/dummy-ramdisk.bin
for v in A B; do
	def=""; [ "$v" = B ] && def="-DDECON_TRIG_WRITE"
	$CC $CFLAGS $def -c start.S -o out/start.o
	$CC $CFLAGS $def -c loader.c -o out/loader.o
	$CC $CFLAGS -c ../fdt.c -o out/fdt.o
	$CC $CFLAGS -static -T loader.ld -Wl,--build-id=none -Wl,-N out/start.o out/loader.o out/fdt.o -o out/loader-$v.elf
	$OBJCOPY -O binary out/loader-$v.elf out/Image-$v
	size=$($NM out/loader-$v.elf | awk '$3=="_end"{print "0x"$1}')
	truncate -s $((size)) out/Image-$v
	python3 -I ../../tools/dreamlte_mkboot.py "$stock" out/Image-$v out/dummy-ramdisk.bin out/stage0-$v.img
	echo "stage0-$v.img: $(wc -c < out/stage0-$v.img) bytes  sha256 $(sha256sum out/stage0-$v.img | cut -d' ' -f1)"
done

# Stage 1: stage 0 (variant B) + read-only UFS probe -> out/stage1-ufs.img
CF="$CFLAGS -DDECON_TRIG_WRITE -DSTAGE1_UFS"
$CC $CF -c start.S -o out/start.o
$CC $CF -c loader.c -o out/loader.o
$CC $CF -c ufs_probe.c -o out/ufs_probe.o
$CC $CFLAGS -c ../fdt.c -o out/fdt.o
$CC $CF -static -T loader.ld -Wl,--build-id=none -Wl,-N out/start.o out/loader.o out/fdt.o out/ufs_probe.o -o out/loader-S1.elf
$OBJCOPY -O binary out/loader-S1.elf out/Image-S1
size=$($NM out/loader-S1.elf | awk '$3=="_end"{print "0x"$1}')
truncate -s $((size)) out/Image-S1
python3 -I ../../tools/dreamlte_mkboot.py "$stock" out/Image-S1 out/dummy-ramdisk.bin out/stage1-ufs.img
echo "stage1-ufs.img: $(wc -c < out/stage1-ufs.img) bytes  sha256 $(sha256sum out/stage1-ufs.img | cut -d' ' -f1)"
