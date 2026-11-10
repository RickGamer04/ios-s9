#!/bin/bash
# dxb runs patches/*.sh from the XNU source root before applying *.patch.
# starlte bring-up: make bsd_init() print every phase on the screen console
# (stock xnu compiles bsd_init_kprintf away), to find where the S9 stops.
set -euo pipefail

case "${MACHINE_CONFIG:-}" in
    A5XELTE) ;;
    *) exit 0 ;;
esac
[[ -f bsd/kern/bsd_init.c ]] || exit 1

python3 - <<'PY'
import re
p = 'bsd/kern/bsd_init.c'
s = open(p).read()
n = 0
s, c = re.subn(r'#define DEBUG_BSDINIT\s+0', '#define DEBUG_BSDINIT 1', s)
n += c
# the macro body: kprintf("bsd_init: " x...) -> printf
s, c = re.subn(r'(#define bsd_init_kprintf\([^\n]*?)kprintf\(', r'\1printf(', s)
n += c
s, c = re.subn(r'kprintf\("bsd_autoconf: calling kminit', lambda m: 'printf("bsd_autoconf: calling kminit', s)
n += c
assert n >= 2, 'bsd_init trace patterns not found (%d)' % n
open(p, 'w').write(s)
print('bsd_init trace: %d substitutions' % n)
PY
grep -n 'DEBUG_BSDINIT\|define bsd_init_kprintf' bsd/kern/bsd_init.c
