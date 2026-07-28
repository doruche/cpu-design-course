#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
selector=${1:-}

case "$selector" in
    c-test-0) source_name=0_uart_test ;;
    c-test-1) source_name=1_formatIO_test ;;
    c-test-2) source_name=2_sort_test ;;
    *) echo "usage: $0 {c-test-0|c-test-1|c-test-2}" >&2; exit 2 ;;
esac

student_id=${STUDENT_ID:-2024311488}
if [[ ! "$student_id" =~ ^[0-9]{8,12}$ ]]; then
    echo "error: STUDENT_ID must contain 8 to 12 decimal digits" >&2
    exit 2
fi

for tool in riscv32-unknown-elf-gcc riscv32-unknown-elf-objcopy \
    riscv32-unknown-elf-objdump python3; do
    command -v "$tool" >/dev/null || {
        echo "error: missing C_TEST build tool: $tool" >&2
        exit 2
    }
done

source_dir="$root/programs/c_test/$source_name"
runtime_dir="$root/programs/c_test/runtime"
output_dir="$root/.cache/programs/c_test/$selector"
prefix="$output_dir/$selector"
rm -rf "$output_dir"
mkdir -p "$output_dir"

sources=("$source_dir/main.c")
if [[ -f "$source_dir/peripheral.h" ]]; then
    sources+=("$runtime_dir/c_test_io.c")
fi
sources+=("$runtime_dir/c_test_runtime.c" "$runtime_dir/start.S")

riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mno-relax \
    -ffunction-sections -fdata-sections -fno-builtin -Os \
    -DC_TEST_STUDENT_ID=\"$student_id\" \
    -I"$runtime_dir/freestanding" \
    -nostdlib -Wl,--build-id=none -Wl,--no-relax -Wl,--gc-sections \
    -T "$runtime_dir/link.ld" -o "$prefix.elf" "${sources[@]}"
riscv32-unknown-elf-objdump -d -s -M no-aliases "$prefix.elf" \
    >"$prefix.dump"
riscv32-unknown-elf-objcopy -O binary "$prefix.elf" "$prefix.raw.bin"

artifact_args=()
artifact_sources=("${sources[@]}" "$runtime_dir/c_test_runtime.h" \
    "$runtime_dir/c_test_io.h" "$runtime_dir/c_test_identity.h" \
    "$runtime_dir/freestanding/stdlib.h" "$runtime_dir/freestanding/string.h" \
    "$runtime_dir/link.ld" \
    "$root/scripts/build-c-test.sh" "$root/scripts/c-test-artifacts.py")
for path in "$source_dir/peripheral.h" "$source_dir/peripheral.c"; do
    [[ -f "$path" ]] && artifact_sources+=("$path")
done
for path in "${artifact_sources[@]}"; do
    artifact_args+=(--source "$path")
done
python3 "$root/scripts/c-test-artifacts.py" \
    --root "$root" --name "$selector" --student-id "$student_id" \
    --elf "$prefix.elf" --dump "$prefix.dump" --raw "$prefix.raw.bin" \
    "${artifact_args[@]}"

printf 'program: %s\n' "$selector"
printf 'program-artifact-directory: %s\n' "${output_dir#"$root/"}"
