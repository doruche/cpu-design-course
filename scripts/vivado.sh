#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$root/scripts/local-settings.sh"
load_local_settings "$root/local.env"

action=${1:-}
candidate=${2:-}
product=${PRODUCT:-single_cycle}
source_dir="$root/projects/$product"

case "$action" in
    stage|synth|bitstream) ;;
    *) echo "usage: $0 {stage|synth|bitstream} [c-test-0|1|2]" >&2; exit 2 ;;
esac

if [[ -n "$candidate" ]]; then
    [[ "$product" == single_cycle ]] || {
        echo "board candidates are only valid for single_cycle" >&2
        exit 2
    }
    case "$candidate" in c-test-0|c-test-1|c-test-2) ;;
        *) echo "unknown board candidate: $candidate" >&2; exit 2 ;;
    esac
fi
if [[ "$product:$action" == single_cycle:bitstream && -z "$candidate" ]]; then
    echo "single-cycle bitstreams require an explicit C_TEST candidate" >&2
    exit 2
fi

if [[ ! -f "$source_dir/miniRV.xpr" ]]; then
    echo "Product is not a staged Vivado project: $source_dir" >&2
    exit 2
fi

if [[ -z "${VIVADO_STAGE_ROOT:-}" ]]; then
    echo "VIVADO_STAGE_ROOT is not set; copy local.env.example to local.env" >&2
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
rsync -a --delete --delete-excluded \
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
if [[ -n $(git -C "$root" status --porcelain --untracked-files=normal) ]]; then
    revision="$revision-dirty"
fi
printf '%s\n' "$revision" >"$stage_dir/.source-revision"
printf 'Staged %s at %s\n' "$product" "$stage_dir"

candidate_coe=-
if [[ -n "$candidate" ]]; then
    candidate_args=(
        --root "$root"
        --stage-dir "$stage_dir"
        --program "$candidate"
    )
    if [[ "$action" == bitstream ]]; then
        candidate_args+=(--require-clean)
    fi
    PYTHONDONTWRITEBYTECODE=1 python3 \
        "$root/scripts/prepare_vivado_candidate.py" "${candidate_args[@]}"
    candidate_coe="$stage_dir/src/coe/$candidate.coe"
fi

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
if [[ "$candidate_coe" == - ]]; then
    candidate_coe_win=-
else
    candidate_coe_win=$(wslpath -w "$candidate_coe")
fi
jobs=${VIVADO_JOBS:-8}
touch "$stage_dir/.build-start"

if [[ "$product" == single_cycle ]]; then
    (
        cd "$stage_dir"
        cmd.exe /d /s /c call "$vivado_win" \
            -mode batch -source "$tcl_win" \
            -tclargs "$action" "$project_win" "$jobs" "$candidate_coe_win"
    )
    PYTHONDONTWRITEBYTECODE=1 python3 \
        "$root/scripts/collect_vivado_evidence.py" \
        --stage-dir "$stage_dir" --action "$action"
else
    (
        cd "$stage_dir"
        cmd.exe /d /s /c call "$vivado_win" \
            -mode batch -source "$tcl_win" \
            -tclargs "$action" "$project_win" "$jobs"
    )
fi

if [[ -n "$candidate" ]]; then
    candidate_output="$stage_root/candidates/$product/$candidate"
    mkdir -p "$candidate_output"
    rsync -a --delete "$stage_dir/artifacts/" "$candidate_output/"
    printf 'Candidate outputs: %s\n' "$candidate_output"
fi
printf 'Vivado %s completed; reports remain in %s/artifacts\n' "$action" "$stage_dir"
