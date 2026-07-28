#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config_file="$root/config/build-configs.tsv"
trace_dir="$root/cdp-tests"
single_rtl="$root/projects/single_cycle/src/rtl"
cache_root="$root/.cache"
export CCACHE_DIR="${CCACHE_DIR:-$cache_root/ccache}"

config_name=
config_product=
config_topology=
config_memory=
config_cache=
config_backend=
config_defines=
config_artifact=

die() {
    printf 'error: %s\n' "$*" >&2
    exit 2
}

list_configs() {
    awk -F '\t' '!/^#/ && NF {print $1}' "$config_file"
}

load_config() {
    local requested=$1
    local record

    record=$(awk -F '\t' -v name="$requested" \
        '!/^#/ && $1 == name {print; found = 1} END {if (!found) exit 1}' \
        "$config_file") || {
        printf 'Unknown configuration: %s\nAvailable configurations:\n' \
            "$requested" >&2
        list_configs | sed 's/^/  /' >&2
        exit 2
    }

    IFS=$'\t' read -r config_name config_product config_topology \
        config_memory config_cache config_backend config_defines \
        config_artifact <<<"$record"

    [[ "$config_backend" == "verilator-trace" ]] || \
        die "unsupported backend in $requested: $config_backend"
    [[ -d "$root/projects/$config_product/src/rtl" ]] || \
        die "missing product RTL: projects/$config_product/src/rtl"
    case "$config_topology:$config_memory:$config_cache" in
        basic:trace-ram:na|axi-direct:trace-bram:bypass|\
        axi-direct:trace-bram:cache|product-soc:trace-bram+mmio:bypass|\
        product-soc:trace-bram+mmio:cache) ;;
        *) die "invalid configuration tuple for $requested" ;;
    esac
}

rtl_dir() {
    printf '%s/projects/%s/src/rtl\n' "$root" "$config_product"
}

mapfile_sorted() {
    local directory=$1
    find "$directory" -maxdepth 1 -type f -name '*.v' -print | sort
}

define_args() {
    local item
    [[ "$config_defines" == "-" ]] && return 0
    IFS=',' read -ra items <<<"$config_defines"
    for item in "${items[@]}"; do
        printf '%s\n' "-D$item"
    done
}

trace_memory_sources() {
    printf '%s\n' "$trace_dir/vsrc/ram.v"
    if [[ "$config_memory" != trace-ram ]]; then
        printf '%s\n' "$trace_dir/vsrc/bram_axi.v"
    fi
}

print_config() {
    local product_rtl
    product_rtl=$(rtl_dir)
    printf 'configuration: %s\n' "$config_name"
    printf '  product: %s\n' "$config_product"
    printf '  topology: %s\n' "$config_topology"
    printf '  memory-model: %s\n' "$config_memory"
    printf '  cache-mode: %s\n' "$config_cache"
    printf '  backend: %s\n' "$config_backend"
    printf '  compiler-defines: %s\n' "$config_defines"
    printf '  artifact-directory: %s\n' "$config_artifact"
    printf '  shared-trace-directory: cdp-tests/obj_dir (serialized)\n'
    printf '  rtl-sources:\n'
    mapfile_sorted "$product_rtl" | sed "s#^$root/#    #"
    printf '  memory-sources:\n'
    trace_memory_sources | sed "s#^$root/#    #"
}

require_product_topology() {
    if [[ "$config_topology" == product-soc ]]; then
        rg -q '(ifdef|elsif) SOC_TOPOLOGY' "$(rtl_dir)/miniRV_SoC.v" || \
            die "$config_name is reserved until checkpoint I3 implements SOC_TOPOLOGY"
    fi
}

lint_config() {
    local product_rtl waiver
    local -a rtl_sources memory_sources defines
    product_rtl=$(rtl_dir)
    waiver="$root/config/verilator-$config_product.vlt"
    mapfile -t rtl_sources < <(mapfile_sorted "$product_rtl")
    mapfile -t memory_sources < <(trace_memory_sources)
    mapfile -t defines < <(define_args)
    [[ -f "$waiver" ]] || die "missing lint waiver: ${waiver#"$root/"}"
    require_product_topology
    print_config
    mkdir -p "$root/$config_artifact"
    verilator --lint-only --Wall -DRUN_TRACE=1 --top-module miniRV_SoC \
        -I"$product_rtl" "${defines[@]}" "$waiver" \
        "${memory_sources[@]}" "${rtl_sources[@]}"
}

trace_prepare_locked() {
    local product_rtl current_file desired
    local -a rtl_sources memory_sources defines sim_opts
    product_rtl=$(rtl_dir)
    current_file="$cache_root/trace/current-config"
    desired=$config_name
    require_product_topology
    mkdir -p "$root/$config_artifact" "$(dirname "$current_file")"
    if [[ ! -f "$current_file" || $(<"$current_file") != "$desired" ]]; then
        make -C "$trace_dir" clean >/dev/null
        printf '%s\n' "$desired" >"$current_file"
    fi
    mapfile -t rtl_sources < <(mapfile_sorted "$product_rtl")
    mapfile -t memory_sources < <(trace_memory_sources)
    mapfile -t defines < <(define_args)
    sim_opts=(--trace -Wno-lint -Wno-style -Wno-TIMESCALEMOD \
        -I"$product_rtl" "${defines[@]}")
    make -C "$trace_dir" build \
        VSRC="${memory_sources[*]} ${rtl_sources[*]}" \
        SIM_OPTS="${sim_opts[*]}"
}

trace_one_locked() {
    local case_name=$1
    [[ -f "$trace_dir/bin/$case_name.bin" ]] || \
        die "unknown Trace case: $case_name"
    trace_prepare_locked
    "$root/scripts/run-trace-suite.sh" "$trace_dir" "$case_name"
}

trace_all_locked() {
    local -a cases
    mapfile -t cases < <(
        find "$trace_dir/bin" -maxdepth 1 -type f -name '*.bin' -printf '%f\n' |
            sed 's/\.bin$//' | sort
    )
    trace_prepare_locked
    "$root/scripts/run-trace-suite.sh" "$trace_dir" "${cases[@]}"
}

with_trace_lock() {
    # Lock the stable repository directory inode so `just clean` can remove
    # all generated outputs without replacing the lock underneath waiters.
    exec 9<"$root"
    flock 9
    "$@"
}

lint_cache_modules() {
    verilator --lint-only --Wall --top-module ICache -DRUN_TRACE=1 \
        -I"$single_rtl" "$single_rtl/ICache.v"
    verilator --lint-only --Wall --top-module ICache -DRUN_TRACE=1 \
        -DENABLE_ICACHE=1 -I"$single_rtl" "$single_rtl/ICache.v"
    verilator --lint-only --Wall --top-module DCache -DRUN_TRACE=1 \
        -I"$single_rtl" "$single_rtl/DCache.v"
    verilator --lint-only --Wall --top-module DCache -DRUN_TRACE=1 \
        -DENABLE_DCACHE=1 -I"$single_rtl" "$single_rtl/DCache.v"
}

unit_cache() {
    local output="$cache_root/unit/cache"
    printf 'unit-suite: cache\n  backend: iverilog+vvp\n  artifact-directory: .cache/unit/cache\n'
    lint_cache_modules
    mkdir -p "$output"
    iverilog -g2012 -Wall -Wno-sensitivity-entire-array -DRUN_TRACE=1 \
        -I"$single_rtl" -s icache_tb -o "$output/icache-bypass" \
        "$single_rtl/ICache.v" "$root/tests/cache/icache_tb.sv"
    vvp "$output/icache-bypass"
    iverilog -g2012 -Wall -Wno-sensitivity-entire-array -DRUN_TRACE=1 \
        -DENABLE_ICACHE=1 -I"$single_rtl" -s icache_tb \
        -o "$output/icache-enabled" \
        "$single_rtl/ICache.v" "$root/tests/cache/icache_tb.sv"
    vvp "$output/icache-enabled"
    iverilog -g2012 -Wall -Wno-sensitivity-entire-array -DRUN_TRACE=1 \
        -I"$single_rtl" -s dcache_tb -o "$output/dcache-bypass" \
        "$single_rtl/DCache.v" "$root/tests/cache/dcache_tb.sv"
    vvp "$output/dcache-bypass"
    iverilog -g2012 -Wall -Wno-sensitivity-entire-array -DRUN_TRACE=1 \
        -DENABLE_DCACHE=1 -I"$single_rtl" -s dcache_tb \
        -o "$output/dcache-enabled" \
        "$single_rtl/DCache.v" "$root/tests/cache/dcache_tb.sv"
    vvp "$output/dcache-enabled"
}

unit_axi_master() {
    local output="$cache_root/unit/axi-master"
    printf 'unit-suite: axi-master\n  backend: iverilog+vvp\n  artifact-directory: .cache/unit/axi-master\n'
    verilator --lint-only --Wall --top-module axi_master -DRUN_TRACE=1 \
        -I"$single_rtl" "$single_rtl/axi_master.v"
    verilator --lint-only --Wall --top-module axi_master -DRUN_TRACE=1 \
        -DENABLE_ICACHE=1 -DENABLE_DCACHE=1 -I"$single_rtl" \
        "$single_rtl/axi_master.v"
    mkdir -p "$output"
    iverilog -g2012 -Wall -DRUN_TRACE=1 -I"$single_rtl" -s axi_master_tb \
        -o "$output/axi-bypass" "$single_rtl/axi_master.v" \
        "$root/tests/axi/axi_master_tb.sv"
    vvp "$output/axi-bypass"
    iverilog -g2012 -Wall -DRUN_TRACE=1 -DENABLE_ICACHE=1 \
        -DENABLE_DCACHE=1 -I"$single_rtl" -s axi_master_tb \
        -o "$output/axi-cache" "$single_rtl/axi_master.v" \
        "$root/tests/axi/axi_master_tb.sv"
    vvp "$output/axi-cache"
}

lint_fabric() {
    verilator --lint-only --Wall --top-module soc_interconnect \
        "$single_rtl/soc_interconnect.v"
    verilator --lint-only --Wall --top-module soc_peripherals \
        -I"$single_rtl" "$single_rtl/soc_peripherals.v" \
        "$single_rtl/seven_segment.v" "$single_rtl/uart_peripheral.v"
}

unit_peripherals() {
    local output="$cache_root/unit/peripherals"
    printf 'unit-suite: peripherals\n  backend: iverilog+vvp\n  artifact-directory: .cache/unit/peripherals\n'
    lint_fabric
    mkdir -p "$output"
    iverilog -g2012 -Wall -I"$single_rtl" -s uart_peripheral_tb \
        -o "$output/uart" "$single_rtl/uart_peripheral.v" \
        "$root/tests/soc_stage3/uart_peripheral_tb.sv"
    vvp "$output/uart"
    iverilog -g2012 -Wall -I"$single_rtl" -s seven_segment_tb \
        -o "$output/seven-segment" "$single_rtl/seven_segment.v" \
        "$root/tests/soc_stage3/seven_segment_tb.sv"
    vvp "$output/seven-segment"
    iverilog -g2012 -Wall -I"$single_rtl" -s timer_peripheral_tb \
        -o "$output/timer" "$single_rtl/soc_peripherals.v" \
        "$single_rtl/seven_segment.v" "$single_rtl/uart_peripheral.v" \
        "$root/tests/soc_stage3/timer_peripheral_tb.sv"
    vvp "$output/timer"
}

unit_stage5_contract() {
    local output="$cache_root/unit/stage5-contract"
    local contract_failed=0
    local -a rtl_sources
    printf 'unit-suite: stage5-contract\n'
    printf '  backend: python3+iverilog+vvp\n'
    printf '  artifact-directory: .cache/unit/stage5-contract\n'
    mkdir -p "$output"
    PYTHONDONTWRITEBYTECODE=1 python3 \
        "$root/tests/stage5/test_contract_tools.py"
    PYTHONDONTWRITEBYTECODE=1 python3 \
        "$root/scripts/stage5_contract.py" --root "$root" || \
        contract_failed=1
    if just --justfile "$root/Justfile" --dry-run \
        vivado-candidate c-test-0 >"$output/candidate-cli.log" 2>&1; then
        printf 'Candidate CLI: explicit c-test-0 selection is available\n'
    else
        cat "$output/candidate-cli.log"
        printf 'FAIL: public Vivado candidate entry is not available\n' >&2
        contract_failed=1
    fi
    mapfile -t rtl_sources < <(mapfile_sorted "$single_rtl")
    iverilog -g2012 -Wall -Wno-sensitivity-entire-array \
        -DPATH="$trace_dir/bin/addi.bin" \
        -I"$single_rtl" -s board_clock_reset_tb \
        -o "$output/board-clock-reset" \
        "$root/tests/stage5/clk_wiz_0_model.v" \
        "${rtl_sources[@]}" "$trace_dir/vsrc/bram_axi.v" \
        "$root/tests/stage5/board_clock_reset_tb.sv"
    vvp "$output/board-clock-reset" || contract_failed=1
    ((contract_failed == 0)) || \
        die "Stage 5 physical contract is not closed"
}

integration_fabric_mmio() {
    local output="$cache_root/integration/fabric-mmio"
    printf 'integration-suite: fabric-mmio\n  backend: iverilog+vvp\n  artifact-directory: .cache/integration/fabric-mmio\n'
    lint_fabric
    mkdir -p "$output"
    iverilog -g2012 -Wall -I"$single_rtl" -s soc_stage3_tb \
        -o "$output/test" "$single_rtl/soc_interconnect.v" \
        "$single_rtl/soc_peripherals.v" "$single_rtl/seven_segment.v" \
        "$single_rtl/uart_peripheral.v" \
        "$root/tests/soc_stage3/soc_stage3_tb.sv"
    vvp "$output/test"
}

integration_dcache_mmio() {
    local output="$cache_root/integration/dcache-mmio"
    printf 'integration-suite: dcache-mmio\n  backend: iverilog+vvp\n  artifact-directory: .cache/integration/dcache-mmio\n'
    lint_fabric
    mkdir -p "$output"
    iverilog -g2012 -Wall -DRUN_TRACE=1 -DENABLE_DCACHE=1 \
        -DPATH="$trace_dir/bin/addi.bin" -I"$single_rtl" \
        -s soc_stage3_full_tb -o "$output/test" \
        "$single_rtl/DCache.v" "$single_rtl/axi_master.v" \
        "$single_rtl/soc_interconnect.v" "$single_rtl/soc_peripherals.v" \
        "$single_rtl/seven_segment.v" "$single_rtl/uart_peripheral.v" \
        "$trace_dir/vsrc/bram_axi.v" \
        "$root/tests/soc_stage3/soc_stage3_full_tb.sv"
    vvp "$output/test"
}

run_unit() {
    case "$1" in
        cache) unit_cache ;;
        axi-master) unit_axi_master ;;
        peripherals) unit_peripherals ;;
        c-test-software) "$root/scripts/run-c-test-software.sh" ;;
        stage5-contract) unit_stage5_contract ;;
        *) die "unknown unit suite: $1 (expected cache, axi-master, peripherals, c-test-software, or stage5-contract)" ;;
    esac
}

run_program() {
    case "$1" in
        c-test-0|c-test-1|c-test-2) "$root/scripts/build-c-test.sh" "$1" ;;
        coremark) "$root/scripts/build-coremark.sh" ;;
        *) die "unknown program: $1 (expected c-test-0, c-test-1, c-test-2, or coremark)" ;;
    esac
}

run_integration() {
    case "$1" in
        fabric-mmio) integration_fabric_mmio ;;
        dcache-mmio) integration_dcache_mmio ;;
        *) die "unknown integration suite: $1 (expected fabric-mmio or dcache-mmio)" ;;
    esac
}

run_system() {
    case "$1" in
        soc-smoke) system_soc_smoke ;;
        c-test-0|c-test-1|c-test-2) system_c_test "$1" ;;
        coremark) system_coremark ;;
        *) die "unknown system suite: $1 (expected soc-smoke, c-test-0..2, or coremark)" ;;
    esac
}

system_c_test() {
    local selector=$1
    local test_id=${selector##*-}
    local output="$cache_root/system/$selector"
    local program="$cache_root/programs/c_test/$selector/$selector.raw.bin"
    local transcript="$output/transcript.txt"
    local -a rtl_sources
    load_config single-soc-cache
    print_config
    printf 'system-suite: %s\n' "$selector"
    printf '  backend: riscv32im-freestanding+iverilog+vvp\n'
    printf '  artifact-directory: .cache/system/%s\n' "$selector"
    run_program "$selector"
    mkdir -p "$output"
    mapfile -t rtl_sources < <(mapfile_sorted "$single_rtl")
    iverilog -g2012 -Wall -Wno-sensitivity-entire-array \
        -DRUN_TRACE=1 -DSIMULATION_CLOCK=1 -DBEHAVIORAL_MEMORY=1 \
        -DSOC_TOPOLOGY=1 -DENABLE_ICACHE=1 -DENABLE_DCACHE=1 \
        -DC_TEST_ID="$test_id" -DPATH="$program" -I"$single_rtl" \
        -s c_test_system_tb -o "$output/c-test-system" \
        "${rtl_sources[@]}" "$trace_dir/vsrc/bram_axi.v" \
        "$root/tests/c_test/c_test_system_tb.sv"
    vvp "$output/c-test-system" "+TRANSCRIPT=$transcript" 2>&1 | \
        tee "$output/system.log"
    python3 "$root/scripts/check-c-test-transcript.py" \
        "$test_id" "$transcript"
}

system_coremark() {
    local output="$cache_root/system/coremark"
    local program="$cache_root/programs/c_test/coremark-sim/coremark-sim.raw.bin"
    local transcript="$output/transcript.txt"
    local product_rtl
    local -a rtl_sources
    load_config pipeline-soc-cache
    print_config
    printf 'system-suite: coremark\n'
    printf '  backend: riscv32im-freestanding+iverilog+vvp\n'
    printf '  artifact-directory: .cache/system/coremark\n'
    # One iteration and no settling delay: the CRCs this proves do not depend on
    # either, and the reported score is only meaningful on the board.
    COREMARK_ITERATIONS=1 COREMARK_INIT_DELAY_MS=0 \
        "$root/scripts/build-coremark.sh" coremark-sim
    mkdir -p "$output"
    product_rtl=$(rtl_dir)
    mapfile -t rtl_sources < <(mapfile_sorted "$product_rtl")
    iverilog -g2012 -Wall -Wno-sensitivity-entire-array \
        -DRUN_TRACE=1 -DSIMULATION_CLOCK=1 -DBEHAVIORAL_MEMORY=1 \
        -DSOC_TOPOLOGY=1 -DENABLE_ICACHE=1 -DENABLE_DCACHE=1 \
        -DPATH="$program" -I"$product_rtl" \
        -s coremark_system_tb -o "$output/coremark-system" \
        "${rtl_sources[@]}" "$trace_dir/vsrc/bram_axi.v" \
        "$root/tests/coremark/coremark_system_tb.sv"
    vvp "$output/coremark-system" "+TRANSCRIPT=$transcript" 2>&1 | \
        tee "$output/system.log"
    python3 "$root/scripts/check-coremark-transcript.py" "$transcript"
}

system_soc_smoke() {
    local output="$cache_root/system/soc-smoke"
    local program="$output/smoke.bin"
    local -a rtl_sources
    load_config single-soc-cache
    print_config
    printf 'system-suite: soc-smoke\n'
    printf '  backend: riscv32-elf+iverilog+vvp\n'
    printf '  artifact-directory: .cache/system/soc-smoke\n'
    "$root/scripts/build-soc-smoke.sh" "$output"
    mapfile -t rtl_sources < <(mapfile_sorted "$single_rtl")
    iverilog -g2012 -Wall -Wno-sensitivity-entire-array \
        -DRUN_TRACE=1 -DSIMULATION_CLOCK=1 -DBEHAVIORAL_MEMORY=1 \
        -DSOC_TOPOLOGY=1 -DENABLE_ICACHE=1 -DENABLE_DCACHE=1 \
        -DPATH="$program" -I"$single_rtl" -s soc_system_tb \
        -o "$output/soc-system" "${rtl_sources[@]}" \
        "$trace_dir/vsrc/bram_axi.v" \
        "$root/tests/soc_system/soc_system_tb.sv"
    vvp "$output/soc-system" 2>&1 | tee "$output/system.log"
}

run_gate() {
    case "$1" in
        single-stage2)
            unit_axi_master
            unit_cache
            lint_config_for single-basic
            lint_config_for single-axi-direct-bypass
            lint_config_for single-axi-direct-cache
            trace_all_for single-basic
            trace_all_for single-axi-direct-bypass
            trace_all_for single-axi-direct-cache
            ;;
        single-stage3)
            integration_fabric_mmio
            unit_peripherals
            integration_dcache_mmio
            run_gate single-stage2
            ;;
        products-basic)
            lint_config_for single-basic
            trace_all_for single-basic
            lint_config_for pipeline-basic
            trace_all_for pipeline-basic
            git -C "$root" diff --check
            ;;
        single-stage4-auto)
            just --justfile "$root/Justfile" --unstable --fmt --check
            "$root/scripts/doctor.sh"
            while IFS= read -r script; do
                bash -n "$script"
            done < <(find "$root/scripts" -maxdepth 1 -type f -name '*.sh' | sort)
            if rg -n 'TODO|20XXXXXXXX|CLOCKS_PER_SEC' \
                "$root/programs/c_test/0_uart_test/main.c" \
                "$root/programs/c_test/1_formatIO_test" \
                "$root/programs/c_test/2_sort_test" \
                "$root/programs/c_test/runtime"; then
                die "C_TEST 0..2 still contain a source placeholder or known typo"
            fi
            "$root/scripts/run-c-test-software.sh"
            for program in c-test-0 c-test-1 c-test-2; do
                run_program "$program"
                system_c_test "$program"
            done
            run_gate closure
            ;;
        closure)
            just --justfile "$root/Justfile" --unstable --fmt --check
            "$root/scripts/doctor.sh"
            unit_cache
            unit_axi_master
            unit_peripherals
            integration_fabric_mmio
            integration_dcache_mmio
            while IFS= read -r config; do
                lint_config_for "$config"
                trace_all_for "$config"
            done < <(list_configs)
            system_soc_smoke
            system_coremark
            xmllint --noout "$root/projects/single_cycle/miniRV.xpr" \
                "$root/projects/pipeline/miniRV.xpr"
            [[ ! -e "$root/Makefile" ]] || die "root Makefile still exists"
            if rg -n '`make |^make ' "$root/README.md" \
                "$root/docs/workflow.md"; then
                die "current README/workflow still expose root make commands"
            fi
            git -C "$root" diff --check
            ;;
        *) die "unknown gate: $1 (expected single-stage2, single-stage3, single-stage4-auto, products-basic, or closure)" ;;
    esac
}

lint_config_for() {
    load_config "$1"
    lint_config
}

trace_all_for() {
    load_config "$1"
    print_config
    mkdir -p "$root/$config_artifact"
    with_trace_lock trace_all_locked 2>&1 | \
        tee "$root/$config_artifact/trace-all.log"
}

run_vivado() {
    local product=$1 action=$2
    case "$product" in single_cycle|pipeline) ;; *) die "unknown product: $product" ;; esac
    case "$action" in stage|synth|bitstream) ;; *) die "unknown Vivado action: $action" ;; esac
    if [[ "$product:$action" == single_cycle:bitstream ]]; then
        die "single-cycle bitstreams require: just vivado-candidate c-test-0|1|2"
    fi
    printf 'vivado-product: %s\nvivado-action: %s\ncanonical-project: projects/%s/miniRV.xpr\n' \
        "$product" "$action" "$product"
    PRODUCT="$product" "$root/scripts/vivado.sh" "$action"
}

run_vivado_candidate() {
    local program=$1 action=$2
    case "$program" in
        c-test-0|c-test-1|c-test-2) ;;
        *) die "unknown Vivado candidate: $program (expected c-test-0..2)" ;;
    esac
    case "$action" in
        stage|bitstream) ;;
        *) die "unknown candidate action: $action (expected stage or bitstream)" ;;
    esac
    run_program "$program"
    printf 'vivado-product: single_cycle\n'
    printf 'vivado-action: %s\n' "$action"
    printf 'vivado-candidate: %s\n' "$program"
    printf 'canonical-project: projects/single_cycle/miniRV.xpr\n'
    PRODUCT=single_cycle "$root/scripts/vivado.sh" "$action" "$program"
}

show_status() {
    git -C "$root" status --short --branch
    git -C "$root" submodule status
    printf '\nStable configurations:\n'
    list_configs | sed 's/^/  /'
    printf '\nVerification suites:\n'
    printf '  unit: cache, axi-master, peripherals, c-test-software, stage5-contract\n'
    printf '  integration: fabric-mmio, dcache-mmio\n'
    printf '  system: soc-smoke, c-test-0, c-test-1, c-test-2, coremark\n'
    printf '  gate: single-stage2, single-stage3, single-stage4-auto, products-basic, closure\n'
    printf '\nBoard programs:\n'
    printf '  c-test-0, c-test-1, c-test-2, coremark\n'
    printf '\nVivado candidates:\n'
    printf '  c-test-0, c-test-1, c-test-2 (stage or bitstream)\n'
}

clean_outputs() {
    with_trace_lock make -C "$trace_dir" clean
    rm -rf "$cache_root"
}

command=${1:-}
case "$command" in
    status)
        [[ $# == 1 ]] || die "usage: $0 status"
        show_status
        ;;
    show-config)
        [[ $# == 2 ]] || die "usage: $0 show-config CONFIG"
        load_config "$2"
        print_config
        ;;
    lint)
        [[ $# == 2 ]] || die "usage: $0 lint CONFIG"
        load_config "$2"
        lint_config
        ;;
    unit)
        [[ $# == 2 ]] || die "usage: $0 unit SUITE"
        run_unit "$2"
        ;;
    program)
        [[ $# == 2 ]] || die "usage: $0 program PROGRAM"
        run_program "$2"
        ;;
    integration)
        [[ $# == 2 ]] || die "usage: $0 integration SUITE"
        run_integration "$2"
        ;;
    trace)
        [[ $# == 3 ]] || die "usage: $0 trace CONFIG CASE"
        load_config "$2"
        print_config
        mkdir -p "$root/$config_artifact"
        with_trace_lock trace_one_locked "$3" 2>&1 | \
            tee "$root/$config_artifact/trace-$3.log"
        ;;
    trace-all)
        [[ $# == 2 ]] || die "usage: $0 trace-all CONFIG"
        load_config "$2"
        print_config
        mkdir -p "$root/$config_artifact"
        with_trace_lock trace_all_locked 2>&1 | \
            tee "$root/$config_artifact/trace-all.log"
        ;;
    system)
        [[ $# == 2 ]] || die "usage: $0 system SUITE"
        run_system "$2"
        ;;
    gate)
        [[ $# == 2 ]] || die "usage: $0 gate GATE"
        run_gate "$2"
        ;;
    vivado)
        [[ $# == 3 ]] || die "usage: $0 vivado PRODUCT ACTION"
        run_vivado "$2" "$3"
        ;;
    vivado-candidate)
        [[ $# == 3 ]] || die "usage: $0 vivado-candidate PROGRAM {stage|bitstream}"
        run_vivado_candidate "$2" "$3"
        ;;
    export-submission)
        [[ $# == 1 ]] || die "usage: $0 export-submission"
        with_trace_lock "$root/scripts/export-submission.sh"
        ;;
    clean)
        [[ $# == 1 ]] || die "usage: $0 clean"
        clean_outputs
        ;;
    *)
        die "usage: $0 {status|show-config|lint|unit|program|integration|trace|trace-all|system|gate|vivado|vivado-candidate|export-submission|clean} ..."
        ;;
esac
