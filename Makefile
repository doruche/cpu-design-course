SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
-include $(ROOT)/local.mk

PRODUCT ?= single_cycle
PRODUCTS := single_cycle pipeline
PROJECT_DIR := $(ROOT)/projects/$(PRODUCT)
RTL_DIR := $(PROJECT_DIR)/src/rtl
SINGLE_CYCLE_RTL_DIR := $(ROOT)/projects/single_cycle/src/rtl
TRACE_DIR := $(ROOT)/cdp-tests
RTL_SOURCES := $(sort $(wildcard $(RTL_DIR)/*.v))
TRACE_PROFILE ?= $(if $(filter single_cycle,$(PRODUCT)),axi,basic)
CACHE ?= off
TRACE_MEMORY_VSRC := $(TRACE_DIR)/vsrc/ram.v \
	$(if $(filter axi,$(TRACE_PROFILE)),$(TRACE_DIR)/vsrc/bram_axi.v)
TRACE_VSRC := $(TRACE_MEMORY_VSRC) $(RTL_SOURCES)
TRACE_DEFINES := $(if $(filter basic,$(TRACE_PROFILE)),-DBASIC_TRACE=1) \
	$(if $(filter on,$(CACHE)),-DENABLE_ICACHE=1 -DENABLE_DCACHE=1)
TRACE_SIM_OPTS := --trace -Wno-lint -Wno-style -Wno-TIMESCALEMOD \
	-I$(RTL_DIR) $(TRACE_DEFINES)
TRACE_TESTS := $(sort $(basename $(notdir $(wildcard $(TRACE_DIR)/bin/*.bin))))
DEMO_TESTS := addi ori slli lw beq bne jal
LINT_WAIVER := $(ROOT)/config/verilator-$(PRODUCT).vlt
TRACE_PROFILE_STAMP := $(ROOT)/.cache/trace-profile

CCACHE_DIR ?= $(ROOT)/.cache/ccache
VIVADO_JOBS ?= 8
CACHE_TEST_DIR := $(ROOT)/tests/cache
CACHE_TEST_BUILD_DIR := $(ROOT)/.cache/cache-tests
AXI_TEST_DIR := $(ROOT)/tests/axi
AXI_TEST_BUILD_DIR := $(ROOT)/.cache/axi-tests

export CCACHE_DIR
export VIVADO_BIN
export VIVADO_STAGE_ROOT
export VIVADO_JOBS

.PHONY: help doctor status lint cache-lint cache-test axi-lint axi-test \
	trace-profile trace-build trace trace-demo trace-all \
	trace-basic trace-basic-all trace-axi trace-axi-all trace-axi-cache \
	trace-axi-cache-all soc-stage2-test \
	trace-clean vivado-stage vivado-synth vivado-bitstream \
	export-submission check check-products clean

help: ## Show available workflow targets.
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target> [VAR=value]\n\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

doctor: ## Check required WSL tools, submodules, and optional Vivado access.
	@$(ROOT)/scripts/doctor.sh

status: ## Show repository, submodule, and selected product status.
	@git status --short --branch
	@git submodule status
	@printf 'product: %s\nrtl: %s\n' '$(PRODUCT)' '$(RTL_DIR)'

lint: ## Strict Verilator lint with only the official template baseline waived.
	@test -d '$(RTL_DIR)' || { echo 'Unknown product: $(PRODUCT)' >&2; exit 2; }
	@test -f '$(LINT_WAIVER)' || { echo 'Missing lint waiver: $(LINT_WAIVER)' >&2; exit 2; }
	@test '$(TRACE_PROFILE)' = basic -o '$(TRACE_PROFILE)' = axi || \
		{ echo 'TRACE_PROFILE must be basic or axi' >&2; exit 2; }
	@test '$(CACHE)' = off -o '$(CACHE)' = on || \
		{ echo 'CACHE must be off or on' >&2; exit 2; }
	@verilator --lint-only --Wall -DRUN_TRACE=1 --top-module miniRV_SoC \
		-I$(RTL_DIR) $(TRACE_DEFINES) '$(LINT_WAIVER)' \
		$(TRACE_MEMORY_VSRC) $(RTL_SOURCES)

cache-lint: ## Lint single-cycle ICache and DCache in bypass and enabled modes.
	@verilator --lint-only --Wall --top-module ICache -DRUN_TRACE=1 \
		-I$(SINGLE_CYCLE_RTL_DIR) $(SINGLE_CYCLE_RTL_DIR)/ICache.v
	@verilator --lint-only --Wall --top-module ICache -DRUN_TRACE=1 -DENABLE_ICACHE=1 \
		-I$(SINGLE_CYCLE_RTL_DIR) $(SINGLE_CYCLE_RTL_DIR)/ICache.v
	@verilator --lint-only --Wall --top-module DCache -DRUN_TRACE=1 \
		-I$(SINGLE_CYCLE_RTL_DIR) $(SINGLE_CYCLE_RTL_DIR)/DCache.v
	@verilator --lint-only --Wall --top-module DCache -DRUN_TRACE=1 -DENABLE_DCACHE=1 \
		-I$(SINGLE_CYCLE_RTL_DIR) $(SINGLE_CYCLE_RTL_DIR)/DCache.v

cache-test: cache-lint ## Run standalone Cache behavior tests in both configurations.
	@mkdir -p '$(CACHE_TEST_BUILD_DIR)'
	@iverilog -g2012 -Wall -Wno-sensitivity-entire-array -DRUN_TRACE=1 \
		-I'$(SINGLE_CYCLE_RTL_DIR)' -s icache_tb \
		-o '$(CACHE_TEST_BUILD_DIR)/icache-bypass' \
		'$(SINGLE_CYCLE_RTL_DIR)/ICache.v' '$(CACHE_TEST_DIR)/icache_tb.sv'
	@vvp '$(CACHE_TEST_BUILD_DIR)/icache-bypass'
	@iverilog -g2012 -Wall -Wno-sensitivity-entire-array -DRUN_TRACE=1 -DENABLE_ICACHE=1 \
		-I'$(SINGLE_CYCLE_RTL_DIR)' \
		-s icache_tb -o '$(CACHE_TEST_BUILD_DIR)/icache-enabled' \
		'$(SINGLE_CYCLE_RTL_DIR)/ICache.v' '$(CACHE_TEST_DIR)/icache_tb.sv'
	@vvp '$(CACHE_TEST_BUILD_DIR)/icache-enabled'
	@iverilog -g2012 -Wall -Wno-sensitivity-entire-array -DRUN_TRACE=1 \
		-I'$(SINGLE_CYCLE_RTL_DIR)' -s dcache_tb \
		-o '$(CACHE_TEST_BUILD_DIR)/dcache-bypass' \
		'$(SINGLE_CYCLE_RTL_DIR)/DCache.v' '$(CACHE_TEST_DIR)/dcache_tb.sv'
	@vvp '$(CACHE_TEST_BUILD_DIR)/dcache-bypass'
	@iverilog -g2012 -Wall -Wno-sensitivity-entire-array -DRUN_TRACE=1 -DENABLE_DCACHE=1 \
		-I'$(SINGLE_CYCLE_RTL_DIR)' \
		-s dcache_tb -o '$(CACHE_TEST_BUILD_DIR)/dcache-enabled' \
		'$(SINGLE_CYCLE_RTL_DIR)/DCache.v' '$(CACHE_TEST_DIR)/dcache_tb.sv'
	@vvp '$(CACHE_TEST_BUILD_DIR)/dcache-enabled'

axi-lint: ## Lint the single-cycle AXI master in bypass and cache-line modes.
	@verilator --lint-only --Wall --top-module axi_master -DRUN_TRACE=1 \
		-I$(SINGLE_CYCLE_RTL_DIR) $(SINGLE_CYCLE_RTL_DIR)/axi_master.v
	@verilator --lint-only --Wall --top-module axi_master \
		-DRUN_TRACE=1 -DENABLE_ICACHE=1 -DENABLE_DCACHE=1 \
		-I$(SINGLE_CYCLE_RTL_DIR) $(SINGLE_CYCLE_RTL_DIR)/axi_master.v

axi-test: axi-lint ## Test AXI arbitration, bursts, backpressure, and write channels.
	@mkdir -p '$(AXI_TEST_BUILD_DIR)'
	@iverilog -g2012 -Wall -DRUN_TRACE=1 -I'$(SINGLE_CYCLE_RTL_DIR)' -s axi_master_tb \
		-o '$(AXI_TEST_BUILD_DIR)/axi-bypass' \
		'$(SINGLE_CYCLE_RTL_DIR)/axi_master.v' '$(AXI_TEST_DIR)/axi_master_tb.sv'
	@vvp '$(AXI_TEST_BUILD_DIR)/axi-bypass'
	@iverilog -g2012 -Wall -DRUN_TRACE=1 -DENABLE_ICACHE=1 -DENABLE_DCACHE=1 \
		-I'$(SINGLE_CYCLE_RTL_DIR)' -s axi_master_tb \
		-o '$(AXI_TEST_BUILD_DIR)/axi-cache' \
		'$(SINGLE_CYCLE_RTL_DIR)/axi_master.v' '$(AXI_TEST_DIR)/axi_master_tb.sv'
	@vvp '$(AXI_TEST_BUILD_DIR)/axi-cache'

trace-profile:
	@test '$(TRACE_PROFILE)' = basic -o '$(TRACE_PROFILE)' = axi || \
		{ echo 'TRACE_PROFILE must be basic or axi' >&2; exit 2; }
	@test '$(CACHE)' = off -o '$(CACHE)' = on || \
		{ echo 'CACHE must be off or on' >&2; exit 2; }
	@mkdir -p '$(dir $(TRACE_PROFILE_STAMP))'
	@key='$(PRODUCT)-$(TRACE_PROFILE)-cache-$(CACHE)'; \
		if test ! -f '$(TRACE_PROFILE_STAMP)' || \
		   test "$$(sed -n '1p' '$(TRACE_PROFILE_STAMP)')" != "$$key"; then \
			$(MAKE) -C '$(TRACE_DIR)' clean >/dev/null; \
			printf '%s\n' "$$key" >'$(TRACE_PROFILE_STAMP)'; \
		fi

trace-build: trace-profile ## Build Trace once against canonical RTL without running a case.
	@test -n '$(RTL_SOURCES)' || { echo 'No RTL sources found under $(RTL_DIR)' >&2; exit 2; }
	@$(MAKE) -C '$(TRACE_DIR)' build \
		VSRC='$(TRACE_VSRC)' SIM_OPTS='$(TRACE_SIM_OPTS)'

trace: trace-profile ## Run one Trace case using the selected Trace profile.
	@test -n '$(TEST)' || { echo 'TEST is required, for example: make trace TEST=addi' >&2; exit 2; }
	@test -f '$(TRACE_DIR)/bin/$(TEST).bin' || { echo 'Unknown Trace test: $(TEST)' >&2; exit 2; }
	@$(MAKE) -C '$(TRACE_DIR)' run TEST='$(TEST)' \
		VSRC='$(TRACE_VSRC)' SIM_OPTS='$(TRACE_SIM_OPTS)'

trace-demo: trace-build ## Run the green official-template baseline suite (seven cases).
	@$(ROOT)/scripts/run-trace-suite.sh '$(TRACE_DIR)' $(DEMO_TESTS)

trace-all: trace-build ## Run every miniRV Trace case in the pinned framework.
	@$(ROOT)/scripts/run-trace-suite.sh '$(TRACE_DIR)' $(TRACE_TESTS)

trace-basic: ## Run one historical Basic Trace case.
	@$(MAKE) trace PRODUCT='$(PRODUCT)' TRACE_PROFILE=basic CACHE=off TEST='$(TEST)'

trace-basic-all: ## Run all historical Basic Trace cases.
	@$(MAKE) trace-all PRODUCT='$(PRODUCT)' TRACE_PROFILE=basic CACHE=off

trace-axi: ## Run one AXI Trace case with caches bypassed.
	@$(MAKE) trace PRODUCT=single_cycle TRACE_PROFILE=axi CACHE=off TEST='$(TEST)'

trace-axi-all: ## Run all AXI Trace cases with caches bypassed.
	@$(MAKE) trace-all PRODUCT=single_cycle TRACE_PROFILE=axi CACHE=off

trace-axi-cache: ## Run one AXI Trace case with both caches enabled.
	@$(MAKE) trace PRODUCT=single_cycle TRACE_PROFILE=axi CACHE=on TEST='$(TEST)'

trace-axi-cache-all: ## Run all AXI Trace cases with both caches enabled.
	@$(MAKE) trace-all PRODUCT=single_cycle TRACE_PROFILE=axi CACHE=on

soc-stage2-test: ## Run the complete automated single-cycle SoC Stage 2 gate.
	@$(MAKE) axi-test
	@$(MAKE) cache-test
	@$(MAKE) lint PRODUCT=single_cycle TRACE_PROFILE=basic CACHE=off
	@$(MAKE) lint PRODUCT=single_cycle TRACE_PROFILE=axi CACHE=off
	@$(MAKE) lint PRODUCT=single_cycle TRACE_PROFILE=axi CACHE=on
	@$(MAKE) trace-basic-all PRODUCT=single_cycle
	@$(MAKE) trace-axi-all
	@$(MAKE) trace-axi-cache-all

trace-clean: ## Remove Trace executable, temporary memory image, and waveforms.
	@$(MAKE) -C '$(TRACE_DIR)' clean

vivado-stage: ## Copy the selected canonical project to disposable Windows staging.
	@PRODUCT='$(PRODUCT)' $(ROOT)/scripts/vivado.sh stage

vivado-synth: ## Stage and run Vivado 2023.2 synthesis in Windows batch mode.
	@PRODUCT='$(PRODUCT)' $(ROOT)/scripts/vivado.sh synth

vivado-bitstream: ## Stage and run implementation, reports, and bitstream generation.
	@PRODUCT='$(PRODUCT)' $(ROOT)/scripts/vivado.sh bitstream

export-submission: ## Build the final course ZIP; requires identity, report, and program variables.
	@$(ROOT)/scripts/export-submission.sh

check: lint trace-all ## Run the current pre-commit checks.
	@git diff --check

check-products: ## Run lint and all Basic Trace cases for both Lab 2 products.
	@for product in $(PRODUCTS); do \
		printf '\n==> Checking %s\n' "$$product"; \
		$(MAKE) trace-clean; \
		$(MAKE) check PRODUCT="$$product" TRACE_PROFILE=basic CACHE=off; \
	 done

clean: trace-clean ## Remove local WSL build outputs.
	@rm -rf '$(ROOT)/.cache'
