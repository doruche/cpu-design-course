#!/usr/bin/env bash
set -u

if (($# < 2)); then
    echo "usage: $0 TRACE_DIR TEST..." >&2
    exit 2
fi

trace_dir=$1
shift
runner="$trace_dir/obj_dir/VminiRV_SoC"

if [[ ! -x "$runner" ]]; then
    echo "Trace runner is missing; run make trace-build first" >&2
    exit 2
fi

passed=()
failed=()

cleanup() {
    rm -f "$trace_dir/meminit.bin"
}
trap cleanup EXIT

for test_name in "$@"; do
    test_bin="$trace_dir/bin/$test_name.bin"
    if [[ ! -f "$test_bin" ]]; then
        echo "Unknown Trace test: $test_name" >&2
        failed+=("$test_name")
        continue
    fi

    printf '\n==================== Testing %s ====================\n' "$test_name"
    ln -sfn "bin/$test_name.bin" "$trace_dir/meminit.bin"
    if (cd "$trace_dir" && "$runner" "$test_name"); then
        passed+=("$test_name")
    else
        failed+=("$test_name")
    fi
done

printf '\n==================== SUMMARY ====================\n'
printf 'Passed (%d): %s\n' "${#passed[@]}" "${passed[*]:-}"
printf 'Failed (%d): %s\n' "${#failed[@]}" "${failed[*]:-}"

((${#failed[@]} == 0))
