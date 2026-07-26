#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
required=(git just make verilator g++ python3 iverilog vvp flock rsync unzip xmllint \
    riscv32-unknown-elf-gcc riscv32-unknown-elf-objcopy riscv32-unknown-elf-objdump)
optional=(gtkwave riscv64-unknown-elf-gcc cmd.exe powershell.exe wslpath)
missing=0

if [[ -f "$root/local.mk" ]]; then
    for name in VIVADO_BIN VIVADO_STAGE_ROOT VIVADO_JOBS; do
        [[ -n "${!name:-}" ]] && continue
        value=$(awk -F ':=' -v key="$name" \
            '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {sub(/^[[:space:]]*/, "", $2); sub(/[[:space:]]*$/, "", $2); print $2}' \
            "$root/local.mk")
        [[ -n "$value" ]] && export "$name=$value"
    done
fi

printf 'Required tools:\n'
for tool in "${required[@]}"; do
    if path=$(command -v "$tool" 2>/dev/null); then
        printf '  [ok] %-28s %s\n' "$tool" "$path"
    else
        printf '  [missing] %s\n' "$tool"
        missing=1
    fi
done

printf '\nOptional tools:\n'
for tool in "${optional[@]}"; do
    if path=$(command -v "$tool" 2>/dev/null); then
        printf '  [ok] %-28s %s\n' "$tool" "$path"
    else
        printf '  [not found] %s\n' "$tool"
    fi
done

printf '\nVersions:\n'
just_version=$(just --version | awk '{print $2}')
minimum_just=1.40.0
if [[ $(printf '%s\n%s\n' "$minimum_just" "$just_version" | sort -V | head -n1) != "$minimum_just" ]]; then
    printf '  just %s is too old; version %s or newer is required\n' \
        "$just_version" "$minimum_just"
    missing=1
else
    printf '  just %s (minimum %s)\n' "$just_version" "$minimum_just"
fi
verilator --version | sed 's/^/  /'
g++ --version | sed -n '1s/^/  /p'
make --version | sed -n '1s/^/  /p'

printf '\nRepository inputs:\n'
for path in \
    "$root/projects/single_cycle/miniRV.xpr" \
    "$root/Justfile" \
    "$root/config/build-configs.tsv" \
    "$root/projects/single_cycle/src/rtl/cpu_core.v" \
    "$root/config/verilator-single_cycle.vlt" \
    "$root/projects/pipeline/miniRV.xpr" \
    "$root/projects/pipeline/src/rtl/cpu_core.v" \
    "$root/config/verilator-pipeline.vlt" \
    "$root/cdp-tests/Makefile" \
    "$root/materials/instruction-site/docs/index.md"; do
    if [[ -e "$path" ]]; then
        printf '  [ok] %s\n' "${path#"$root/"}"
    else
        printf '  [missing] %s\n' "${path#"$root/"}"
        missing=1
    fi
done

if git -C "$root" submodule status | grep -qE '^[-+]'; then
    printf '  [error] submodules are uninitialized or differ from the pinned commits\n'
    missing=1
else
    printf '  [ok] submodules match the parent repository\n'
fi

printf '\nVivado batch access:\n'
if [[ -n "${VIVADO_BIN:-}" && -f "${VIVADO_BIN}" ]]; then
    printf '  [ok] %s\n' "$VIVADO_BIN"
else
    printf '  [not configured] copy local.mk.example to local.mk after installing Vivado 2023.2\n'
fi

if ((missing)); then
    exit 1
fi
