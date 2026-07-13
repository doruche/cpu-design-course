#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${STUDENT_ID:?Set STUDENT_ID}"
: "${STUDENT_NAME:?Set STUDENT_NAME}"
: "${REPORT_PDF:?Set REPORT_PDF to the final report path}"
: "${PROGRAM_ASM:?Set PROGRAM_ASM to the final board-program assembly path}"
: "${PROGRAM_COE:?Set PROGRAM_COE to the COE generated from PROGRAM_ASM}"

for path in "$REPORT_PDF" "$PROGRAM_ASM" "$PROGRAM_COE"; do
    [[ -f "$path" ]] || { echo "Required file is missing: $path" >&2; exit 2; }
done

for product in single_cycle pipeline; do
    [[ -d "$root/projects/$product/src/rtl" ]] || {
        echo "Missing final product: projects/$product" >&2
        exit 2
    }
done

command -v zip >/dev/null || { echo "zip is required" >&2; exit 2; }

package_name="${STUDENT_ID}_${STUDENT_NAME}_comp2012"
package_root="$root/dist/$package_name"
trace_dir="$root/cdp-tests"
rm -rf "$package_root"
mkdir -p "$package_root/single_cycle" "$package_root/pipeline"
cp "$REPORT_PDF" "$package_root/${STUDENT_ID}_${STUDENT_NAME}.pdf"

for product in single_cycle pipeline; do
    destination="$package_root/$product"
    while IFS= read -r -d '' source; do
        basename=${source##*/}
        [[ ! -e "$destination/$basename" ]] || {
            echo "Duplicate flattened RTL filename: $basename" >&2
            exit 2
        }
        cp "$source" "$destination/$basename"
    done < <(find "$root/projects/$product/src/rtl" -type f \
        \( -name '*.v' -o -name '*.vh' \) -not -path '*/ip/*' -print0)

    cp "$PROGRAM_ASM" "$PROGRAM_COE" "$destination/"
done

trace_tests=()
while IFS= read -r test_bin; do
    test_name=${test_bin##*/}
    trace_tests+=("${test_name%.bin}")
done < <(find "$trace_dir/bin" -maxdepth 1 -type f -name '*.bin' | sort)

for product in single_cycle pipeline; do
    rtl_dir="$package_root/$product"
    rtl_sources=("$rtl_dir"/*.v)
    trace_vsrc="$trace_dir/vsrc/bram_axi.v $trace_dir/vsrc/ram.v ${rtl_sources[*]}"
    trace_opts="--trace -Wno-lint -Wno-style -Wno-TIMESCALEMOD -I$rtl_dir"

    printf 'Verifying exported %s RTL with all Trace cases...\n' "$product"
    make -C "$trace_dir" clean
    make -C "$trace_dir" build VSRC="$trace_vsrc" SIM_OPTS="$trace_opts"
    "$root/scripts/run-trace-suite.sh" "$trace_dir" "${trace_tests[@]}"
done

(cd "$root/dist" && zip -qr "$package_name.zip" "$package_name")
printf 'Created %s\n' "$root/dist/$package_name.zip"
