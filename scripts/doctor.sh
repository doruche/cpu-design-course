#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$root/scripts/local-settings.sh"
local_settings_ok=1
if ! load_local_settings "$root/local.env"; then
    local_settings_ok=0
fi

required=(git just make cc verilator g++ python3 iverilog vvp flock rg rsync unzip xmllint \
    riscv32-unknown-elf-gcc riscv32-unknown-elf-objcopy \
    riscv32-unknown-elf-objdump riscv32-unknown-elf-readelf)
optional=(gtkwave riscv64-unknown-elf-gcc)
missing=0

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

printf '\nRV32IM/ILP32 runtime ABI:\n'
if command -v riscv32-unknown-elf-gcc >/dev/null && \
    command -v riscv32-unknown-elf-readelf >/dev/null; then
    rv32_probe_elf=$(mktemp /tmp/cpu-design-rv32-abi.XXXXXX)
    trap 'rm -f "$rv32_probe_elf"' EXIT
    if printf '%s\n' \
        'volatile float probe_a = 1.0f;' \
        'volatile float probe_b = 3.0f;' \
        'volatile unsigned long long probe_n = 0x100000001ULL;' \
        'int main(void) {' \
        '    return (int)(probe_a / probe_b) + (int)(probe_n / 3ULL);' \
        '}' | \
        riscv32-unknown-elf-gcc \
            -march=rv32im -mabi=ilp32 -mno-relax \
            -ffreestanding -fno-builtin -nostdlib \
            -Wl,--build-id=none -Wl,--no-relax \
            -T "$root/programs/c_test/runtime/link.ld" \
            -x c - \
            -x assembler-with-cpp "$root/programs/c_test/runtime/start.S" \
            -x none -lgcc -o "$rv32_probe_elf"; then
        rv32_probe_header=$(riscv32-unknown-elf-readelf -h "$rv32_probe_elf")
        rv32_probe_attributes=$(riscv32-unknown-elf-readelf -A "$rv32_probe_elf")
        rv32_probe_symbols=$(riscv32-unknown-elf-readelf -s "$rv32_probe_elf")
        if [[ "$rv32_probe_header" == *"Class:                             ELF32"* &&
              "$rv32_probe_header" == *"Machine:                           RISC-V"* &&
              "$rv32_probe_attributes" == *'Tag_RISCV_arch: "rv32i'* &&
              "$rv32_probe_attributes" == *'_m'* &&
              "$rv32_probe_symbols" == *"__divsf3"* &&
              "$rv32_probe_symbols" == *"__udivdi3"* ]]; then
            printf '  [ok] RV32IM/ILP32 compile+link with soft-float and 64-bit libgcc helpers\n'
        else
            printf '  [error] linked probe is not the required RV32IM/ILP32 runtime ABI\n'
            missing=1
        fi
    else
        printf '  [error] RV32IM/ILP32 compile+link probe failed\n'
        missing=1
    fi
else
    printf '  [not run] required RISC-V compiler/readelf is unavailable\n'
fi

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
    "$root/tests/cdp/Makefile" \
    "$root/docs/instruction-site/index.md"; do
    if [[ -e "$path" ]]; then
        printf '  [ok] %s\n' "${path#"$root/"}"
    else
        printf '  [missing] %s\n' "${path#"$root/"}"
        missing=1
    fi
done

printf '\nWSL/Windows Vivado backend (optional):\n'
if (( ! local_settings_ok )); then
    printf '  [misconfigured] local.env is invalid; Vivado commands will fail closed\n'
elif [[ -z "${VIVADO_STAGE_ROOT:-}" ]]; then
    printf '  [not configured] VIVADO_STAGE_ROOT is required by just vivado ... stage\n'
else
    printf '  [configured] VIVADO_STAGE_ROOT=%s (must be Windows-visible and disposable)\n' \
        "$VIVADO_STAGE_ROOT"
fi

if ((local_settings_ok)); then
    if [[ -n "${VIVADO_BIN:-}" && -f "${VIVADO_BIN}" ]]; then
        printf '  [configured] VIVADO_BIN=%s\n' "$VIVADO_BIN"
    else
        printf '  [not configured] VIVADO_BIN must name Windows Vivado 2023.2 vivado.bat\n'
    fi

    if [[ -n "${VIVADO_JOBS:-}" ]]; then
        printf '  [configured] VIVADO_JOBS=%s\n' "$VIVADO_JOBS"
    else
        printf '  [default] VIVADO_JOBS=8\n'
    fi

    vivado_bridge_missing=0
    for tool in cmd.exe wslpath; do
        if path=$(command -v "$tool" 2>/dev/null); then
            printf '  [ok] %-28s %s\n' "$tool" "$path"
        else
            printf '  [not available] %s is required for Vivado synth and bitstream\n' \
                "$tool"
            vivado_bridge_missing=1
        fi
    done

    if [[ -n "${VIVADO_STAGE_ROOT:-}" && -n "${VIVADO_BIN:-}" && \
          -f "${VIVADO_BIN}" && $vivado_bridge_missing == 0 ]]; then
        printf '  [ready] configured for Vivado staging and batch actions; no action was run\n'
    else
        printf '  [not ready] configure the missing optional Vivado prerequisites above\n'
    fi
fi

if ((missing)); then
    exit 1
fi
