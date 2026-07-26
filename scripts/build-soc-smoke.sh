#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_dir=${1:-}
[[ -n "$output_dir" ]] || {
    echo "usage: $0 OUTPUT_DIR" >&2
    exit 2
}

for tool in riscv32-unknown-elf-gcc riscv32-unknown-elf-objcopy \
    riscv32-unknown-elf-objdump; do
    command -v "$tool" >/dev/null || {
        echo "missing SoC smoke build tool: $tool" >&2
        exit 2
    }
done

mkdir -p "$output_dir"
riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mno-relax \
    -nostdlib -nostartfiles -Wl,--build-id=none -Wl,--no-relax \
    -T "$root/tests/soc_system/link.ld" \
    -o "$output_dir/smoke.elf" "$root/tests/soc_system/smoke.S"
riscv32-unknown-elf-objcopy -O binary \
    "$output_dir/smoke.elf" "$output_dir/smoke.bin"
riscv32-unknown-elf-objdump -d "$output_dir/smoke.elf" \
    >"$output_dir/smoke.dump"

printf 'program-source: tests/soc_system/smoke.S\n'
printf 'program-elf: %s\n' "${output_dir#"$root/"}/smoke.elf"
printf 'program-binary: %s\n' "${output_dir#"$root/"}/smoke.bin"
