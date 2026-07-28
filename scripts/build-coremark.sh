#!/usr/bin/env bash
set -euo pipefail

# CoreMark is built separately from the C_TEST programs: it keeps the benchmark's
# own optimisation contract, links its own output and timing port instead of the
# repository I/O layer, and needs libgcc for the soft-float and 64-bit helpers.

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# The board image and the short image the RTL system suite runs differ only in
# iteration count and settling delay, so they are kept in separate directories
# rather than overwriting one another.
selector=${1:-coremark}
case "$selector" in
    coremark|coremark-sim) ;;
    *) echo "usage: $0 [coremark|coremark-sim]" >&2; exit 2 ;;
esac

iterations=${COREMARK_ITERATIONS:-700}
if [[ ! "$iterations" =~ ^[0-9]+$ ]] || (( iterations == 0 )); then
    echo "error: COREMARK_ITERATIONS must be a positive integer" >&2
    exit 2
fi

init_delay_ms=${COREMARK_INIT_DELAY_MS:-100}
if [[ ! "$init_delay_ms" =~ ^[0-9]+$ ]]; then
    echo "error: COREMARK_INIT_DELAY_MS must be a non-negative integer" >&2
    exit 2
fi

student_id=${STUDENT_ID:-2024311488}
if [[ ! "$student_id" =~ ^[0-9]{8,12}$ ]]; then
    echo "error: STUDENT_ID must contain 8 to 12 decimal digits" >&2
    exit 2
fi

for tool in riscv32-unknown-elf-gcc riscv32-unknown-elf-objcopy \
    riscv32-unknown-elf-objdump python3; do
    command -v "$tool" >/dev/null || {
        echo "error: missing CoreMark build tool: $tool" >&2
        exit 2
    }
done

source_dir="$root/programs/c_test/4_coremark/src"
runtime_dir="$root/programs/c_test/runtime"
output_dir="$root/.cache/programs/c_test/$selector"
prefix="$output_dir/$selector"
rm -rf "$output_dir"
mkdir -p "$output_dir"

# The flags CoreMark's own common.mk applies; they belong in the reported score.
optimization=(-O2 -funroll-loops -fpeel-loops -fgcse-sm -fgcse-las)

sources=("$source_dir/coremark/core_portme.c"
    "$source_dir/coremark/src/core_list_join.c"
    "$source_dir/coremark/src/core_main.c"
    "$source_dir/coremark/src/core_matrix.c"
    "$source_dir/coremark/src/core_state.c"
    "$source_dir/coremark/src/core_util.c"
    "$source_dir/common/sc_print.c"
    "$runtime_dir/c_test_runtime.c"
    "$runtime_dir/start.S")

riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mno-relax \
    -std=gnu99 -fno-common -fno-builtin "${optimization[@]}" \
    -ffunction-sections -fdata-sections \
    -DITERATIONS="$iterations" -DPERFORMANCE_RUN=1 -DHAS_STDIO=0 \
    -DCOREMARK_INIT_DELAY_MS="$init_delay_ms" \
    -DFLAGS_STR="\"${optimization[*]}\"" \
    -I"$source_dir/coremark" -I"$source_dir/coremark/src" \
    -I"$source_dir/common" -I"$runtime_dir" -I"$runtime_dir/freestanding" \
    -nostdlib -Wl,--build-id=none -Wl,--no-relax -Wl,--gc-sections \
    -T "$runtime_dir/link.ld" -o "$prefix.elf" "${sources[@]}" -lgcc
riscv32-unknown-elf-objdump -d -s -M no-aliases "$prefix.elf" \
    >"$prefix.dump"
riscv32-unknown-elf-objcopy -O binary "$prefix.elf" "$prefix.raw.bin"

artifact_args=()
artifact_sources=("${sources[@]}"
    "$source_dir/coremark/core_portme.h"
    "$source_dir/coremark/src/coremark.h"
    "$source_dir/common/sc_print.h"
    "$runtime_dir/c_test_runtime.h"
    "$runtime_dir/freestanding/stdio.h"
    "$runtime_dir/freestanding/stdlib.h"
    "$runtime_dir/freestanding/string.h"
    "$runtime_dir/link.ld"
    "$root/scripts/build-coremark.sh" "$root/scripts/c-test-artifacts.py")
for path in "${artifact_sources[@]}"; do
    artifact_args+=(--source "$path")
done
python3 "$root/scripts/c-test-artifacts.py" \
    --root "$root" --name "$selector" --student-id "$student_id" \
    --elf "$prefix.elf" --dump "$prefix.dump" --raw "$prefix.raw.bin" \
    "${artifact_args[@]}"

printf 'program: %s\n' "$selector"
printf 'program-coremark-iterations: %s\n' "$iterations"
printf 'program-coremark-init-delay-ms: %s\n' "$init_delay_ms"
printf 'program-artifact-directory: %s\n' "${output_dir#"$root/"}"
