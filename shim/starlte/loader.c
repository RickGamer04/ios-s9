/* SPDX-License-Identifier: GPL-2.0-only
 * Galaxy S9 (SM-G960F, Exynos 9810) diagnostic loader, stage 0.
 * Does NOTHING but draw text on the S-Boot framebuffer: no UFS, PMIC,
 * touch, SMP or XNU. Answers: does S-Boot run our BOOT image, at which EL,
 * and what does the screen show.
 * Adapted from the ios-galaxy-s8 loader (shim/dreamlte/loader.c).
 */
#include <stdint.h>
#include "../fdt.h"
#include "../font.h"
#ifdef STAGE1_UFS
#include "ufs_probe.h"
#define UFS_PROBE_DMA 0x8f0000000UL
#endif

#define FB_BASE		0xcc000000UL	/* s3cfb.bootloaderfb (cmdline) */
#define FB_W		1440
#define FB_H		2960
#define FB_STRIDE	(FB_W * 4)
#define DECON_TRIG	0x16030070UL	/* DECON_F 0x16030000 + 0x70 (as on S8) */
#define DECON_TRIG_UNMASK 0x1281U

static volatile uint32_t *const fb = (volatile uint32_t *)FB_BASE;
#define SCALE	3
#define CELL_W	(8 * SCALE)
#define CELL_H	(16 * SCALE + 6)
#define COLS	((FB_W - 48) / CELL_W)
#define ROWS	((FB_H - 160) / CELL_H)
static int row, col;
static uint32_t fg = 0xffffffffU;

static void fill(int x0, int y0, int w, int h, uint32_t c)
{
	for (int y = y0; y < y0 + h && y < FB_H; y++)
		for (int x = x0; x < x0 + w && x < FB_W; x++)
			fb[y * (FB_STRIDE / 4) + x] = c;
}

static void scr_ch(char c)
{
	if (c == '\n' || col >= COLS) {
		col = 0;
		row = (row + 1) % ROWS;
		fill(0, 120 + row * CELL_H, FB_W, CELL_H, 0xff000000U);
		if (c == '\n')
			return;
	}
	if (c < 0x20 || c > 0x7e)
		c = '?';
	const unsigned char *g = font8x16[c - 0x20];
	int x0 = 24 + col * CELL_W, y0 = 120 + row * CELL_H;
	for (int gy = 0; gy < 16; gy++)
		for (int gx = 0; gx < 8; gx++)
			fill(x0 + gx * SCALE, y0 + gy * SCALE, SCALE, SCALE,
			     (g[gy] & (0x80 >> gx)) ? fg : 0xff000000U);
	col++;
}

static void out(const char *s)
{
	while (*s)
		scr_ch(*s++);
}

static void hex(uint64_t v)
{
	static const char digits[] = "0123456789abcdef";
	char b[19] = "0x";
	int n = 2, started = 0;
	for (int i = 60; i >= 0; i -= 4) {
		int d = (v >> i) & 0xf;
		if (d || started || i == 0) {
			b[n++] = digits[d];
			started = 1;
		}
	}
	b[n] = 0;
	out(b);
}

static void kv(const char *k, uint64_t v)
{
	out(k);
	out("=");
	hex(v);
	out("\n");
}

uint64_t dl_boot_args;	/* read by start.S */

uint64_t dl_main(uintptr_t dtb, uint64_t el, uint64_t sctlr)
{
#ifdef DECON_TRIG_WRITE
	*(volatile uint32_t *)DECON_TRIG = DECON_TRIG_UNMASK;
#endif
	fill(0, 0, FB_W, FB_H, 0xff000000U);
	fg = 0xffffff00U;
#ifdef DECON_TRIG_WRITE
	out("S9LOADER STAGE0 (variant B: DECON trigger written)\n");
#else
	out("S9LOADER STAGE0 (variant A: no DECON write)\n");
#endif
	fg = 0xffffffffU;
	uint64_t midr, mpidr, cntfrq;
	__asm__ volatile("mrs %0, midr_el1" : "=r"(midr));
	__asm__ volatile("mrs %0, mpidr_el1" : "=r"(mpidr));
	__asm__ volatile("mrs %0, cntfrq_el0" : "=r"(cntfrq));
	kv("EL", el);
	kv("SCTLR_EL1", sctlr);
	kv("DTB", dtb);
	kv("MIDR", midr);
	kv("MPIDR", mpidr);
	kv("CNTFRQ", cntfrq);
	uint64_t a, b;
	if (fdt_chosen_u64(dtb, "linux,initrd-start", &a) &&
	    fdt_chosen_u64(dtb, "linux,initrd-end", &b)) {
		kv("initrd", a);
		kv("initrd_end", b);
	} else {
		out("no initrd in /chosen\n");
	}
#ifdef STAGE1_UFS
	out("\nUFS read-only probe...\n");
	ufs_probe(kv, out, UFS_PROBE_DMA);
#endif
	fg = 0xff40ff40U;
	out("\nSTAGE DONE. Nothing else done.\n");
	out("Hold POWER+VOL DOWN, then POWER+BIXBY+VOL UP -> TWRP\n");
	return 0;	/* start.S parks in wfe */
}

void dl_exception(uint64_t slot)
{
	uint64_t esr, elr, far;
	__asm__ volatile("mrs %0, esr_el1" : "=r"(esr));
	__asm__ volatile("mrs %0, elr_el1" : "=r"(elr));
	__asm__ volatile("mrs %0, far_el1" : "=r"(far));
	fg = 0xffff4040U;
	out("\nLOADER EXCEPTION\n");
	kv("slot", slot);
	kv("ESR", esr);
	kv("ELR", elr);
	kv("FAR", far);
	for (;;)
		__asm__ volatile("wfe");
}

void *memset(void *d, int c, unsigned long n)
{
	unsigned char *q = d;
	while (n--)
		*q++ = (unsigned char)c;
	return d;
}

void *memcpy(void *d, const void *s, unsigned long n)
{
	unsigned char *q = d;
	const unsigned char *r = s;
	while (n--)
		*q++ = *r++;
	return d;
}
