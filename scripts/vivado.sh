#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
action=${1:-}
product=${PRODUCT:-single_cycle}
source_dir="$root/projects/$product"

case "$action" in
    stage|synth|bitstream) ;;
    *) echo "usage: $0 {stage|synth|bitstream}" >&2; exit 2 ;;
esac

if [[ ! -f "$source_dir/miniRV.xpr" ]]; then
    echo "Product is not a staged Vivado project: $source_dir" >&2
    exit 2
fi

if [[ -z "${VIVADO_STAGE_ROOT:-}" ]]; then
    echo "VIVADO_STAGE_ROOT is not set; copy local.mk.example to local.mk" >&2
    exit 2
fi

stage_root=${VIVADO_STAGE_ROOT%/}
stage_dir="$stage_root/$product"

case "$stage_dir" in
    "$source_dir"|"$source_dir"/*)
        echo "Vivado staging must not be inside the canonical project" >&2
        exit 2
        ;;
esac

mkdir -p "$stage_dir"
rsync -a --delete \
    --exclude='.Xil/' \
    --exclude='*.cache/' \
    --exclude='*.gen/' \
    --exclude='*.hw/' \
    --exclude='*.ip_user_files/' \
    --exclude='*.runs/' \
    --exclude='*.sim/' \
    --exclude='*.srcs/' \
    --exclude='*.jou' \
    --exclude='*.log' \
    --exclude='*.pb' \
    --exclude='*.str' \
    --exclude='*.wdb' \
    --exclude='*.vcd' \
    --exclude='*.fst' \
    --exclude='*.bit' \
    --exclude='*.ltx' \
    --include='src/rtl/ip/' \
    --include='src/rtl/ip/*/' \
    --include='src/rtl/ip/*/*.xci' \
    --exclude='src/rtl/ip/***' \
    "$source_dir/" "$stage_dir/"

revision=$(git -C "$root" rev-parse HEAD)
if [[ -n $(git -C "$root" status --porcelain --untracked-files=no) ]]; then
    revision="$revision-dirty"
fi
printf '%s\n' "$revision" >"$stage_dir/.source-revision"
printf 'Staged %s at %s\n' "$product" "$stage_dir"

if [[ "$action" == stage ]]; then
    exit 0
fi

for tool in cmd.exe wslpath; do
    command -v "$tool" >/dev/null || { echo "$tool is required for Windows Vivado" >&2; exit 2; }
done

if [[ -z "${VIVADO_BIN:-}" || ! -f "${VIVADO_BIN}" ]]; then
    echo "VIVADO_BIN does not name an installed Vivado 2023.2 vivado.bat" >&2
    exit 2
fi

vivado_win=$(wslpath -w "$VIVADO_BIN")
tcl_win=$(wslpath -w "$stage_dir/scripts/build.tcl")
project_win=$(wslpath -w "$stage_dir/miniRV.xpr")
jobs=${VIVADO_JOBS:-8}

cmd.exe /d /s /c "\"$vivado_win\" -mode batch -source \"$tcl_win\" -tclargs $action \"$project_win\" $jobs"
printf 'Vivado %s completed; reports remain in %s/artifacts\n' "$action" "$stage_dir"
