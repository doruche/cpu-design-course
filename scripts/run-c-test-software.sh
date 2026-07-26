#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output="$root/.cache/unit/c-test-software"
runtime="$root/programs/c_test/runtime"
test_source="$root/tests/c_test/c_test_software_tb.c"

mkdir -p "$output"

cc -std=c11 -Wall -Wextra -Werror -DC_TEST_HOST=1 \
    -DTEST_UART_FORMAT=1 -I"$runtime" \
    -I"$root/programs/c_test/1_formatIO_test" \
    "$test_source" "$runtime/c_test_io.c" \
    -o "$output/uart-format"
"$output/uart-format"

cc -std=c11 -Wall -Wextra -Werror -DC_TEST_HOST=1 \
    -DC_TEST_STUDENT_ID=\"TEST\" -DTEST_TIMER_SORT_HEAP=1 \
    -I"$runtime" -I"$root/programs/c_test/2_sort_test" \
    "$test_source" "$runtime/c_test_runtime.c" \
    "$runtime/c_test_io.c" \
    "$root/programs/c_test/2_sort_test/main.c" \
    -o "$output/timer-sort-heap"
"$output/timer-sort-heap"
