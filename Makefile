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
TRACE_VSRC := $(TRACE_DIR)/vsrc/bram_axi.v $(TRACE_DIR)/vsrc/ram.v $(RTL_SOURCES)
TRACE_SIM_OPTS := --trace -Wno-lint -Wno-style -Wno-TIMESCALEMOD -I$(RTL_DIR)
TRACE_TESTS := $(sort $(basename $(notdir $(wildcard $(TRACE_DIR)/bin/*.bin))))
DEMO_TESTS := addi ori slli lw beq bne jal
LINT_WAIVER := $(ROOT)/config/verilator-$(PRODUCT).vlt

CCACHE_DIR ?= $(ROOT)/.cache/ccache
VIVADO_JOBS ?= 8
CACHE_TEST_DIR := $(ROOT)/tests/cache
CACHE_TEST_BUILD_DIR := $(ROOT)/.cache/cache-tests

export CCACHE_DIR
export VIVADO_BIN
export VIVADO_STAGE_ROOT
export VIVADO_JOBS

.PHONY: help doctor status lint cache-lint cache-test \
	trace-build trace trace-demo trace-all \
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
	@verilator --lint-only --Wall -DRUN_TRACE=1 --top-module miniRV_SoC \
		-I$(RTL_DIR) '$(LINT_WAIVER)' \
		$(TRACE_DIR)/vsrc/ram.v $(RTL_SOURCES)

cache-lint: ## Lint single-cycle ICache and DCache in bypass and enabled modes.
	@verilator --lint-only --Wall --top-module ICache \
		-I$(SINGLE_CYCLE_RTL_DIR) $(SINGLE_CYCLE_RTL_DIR)/ICache.v
	@verilator --lint-only --Wall --top-module ICache -DENABLE_ICACHE=1 \
		-I$(SINGLE_CYCLE_RTL_DIR) $(SINGLE_CYCLE_RTL_DIR)/ICache.v
	@verilator --lint-only --Wall --top-module DCache \
		-I$(SINGLE_CYCLE_RTL_DIR) $(SINGLE_CYCLE_RTL_DIR)/DCache.v
	@verilator --lint-only --Wall --top-module DCache -DENABLE_DCACHE=1 \
		-I$(SINGLE_CYCLE_RTL_DIR) $(SINGLE_CYCLE_RTL_DIR)/DCache.v

cache-test: cache-lint ## Run standalone Cache behavior tests in both configurations.
	@mkdir -p '$(CACHE_TEST_BUILD_DIR)'
	@iverilog -g2012 -Wall -Wno-sensitivity-entire-array \
		-I'$(SINGLE_CYCLE_RTL_DIR)' -s icache_tb \
		-o '$(CACHE_TEST_BUILD_DIR)/icache-bypass' \
		'$(SINGLE_CYCLE_RTL_DIR)/ICache.v' '$(CACHE_TEST_DIR)/icache_tb.sv'
	@vvp '$(CACHE_TEST_BUILD_DIR)/icache-bypass'
	@iverilog -g2012 -Wall -Wno-sensitivity-entire-array -DENABLE_ICACHE=1 \
		-I'$(SINGLE_CYCLE_RTL_DIR)' \
		-s icache_tb -o '$(CACHE_TEST_BUILD_DIR)/icache-enabled' \
		'$(SINGLE_CYCLE_RTL_DIR)/ICache.v' '$(CACHE_TEST_DIR)/icache_tb.sv'
	@vvp '$(CACHE_TEST_BUILD_DIR)/icache-enabled'
	@iverilog -g2012 -Wall -Wno-sensitivity-entire-array \
		-I'$(SINGLE_CYCLE_RTL_DIR)' -s dcache_tb \
		-o '$(CACHE_TEST_BUILD_DIR)/dcache-bypass' \
		'$(SINGLE_CYCLE_RTL_DIR)/DCache.v' '$(CACHE_TEST_DIR)/dcache_tb.sv'
	@vvp '$(CACHE_TEST_BUILD_DIR)/dcache-bypass'
	@iverilog -g2012 -Wall -Wno-sensitivity-entire-array -DENABLE_DCACHE=1 \
		-I'$(SINGLE_CYCLE_RTL_DIR)' \
		-s dcache_tb -o '$(CACHE_TEST_BUILD_DIR)/dcache-enabled' \
		'$(SINGLE_CYCLE_RTL_DIR)/DCache.v' '$(CACHE_TEST_DIR)/dcache_tb.sv'
	@vvp '$(CACHE_TEST_BUILD_DIR)/dcache-enabled'

trace-build: ## Build Trace once against canonical RTL without running a case.
	@test -n '$(RTL_SOURCES)' || { echo 'No RTL sources found under $(RTL_DIR)' >&2; exit 2; }
	@$(MAKE) -C '$(TRACE_DIR)' build \
		VSRC='$(TRACE_VSRC)' SIM_OPTS='$(TRACE_SIM_OPTS)'

trace: ## Run one Trace case, for example: make trace TEST=addi.
	@test -n '$(TEST)' || { echo 'TEST is required, for example: make trace TEST=addi' >&2; exit 2; }
	@test -f '$(TRACE_DIR)/bin/$(TEST).bin' || { echo 'Unknown Trace test: $(TEST)' >&2; exit 2; }
	@$(MAKE) -C '$(TRACE_DIR)' run TEST='$(TEST)' \
		VSRC='$(TRACE_VSRC)' SIM_OPTS='$(TRACE_SIM_OPTS)'

trace-demo: trace-build ## Run the green official-template baseline suite (seven cases).
	@$(ROOT)/scripts/run-trace-suite.sh '$(TRACE_DIR)' $(DEMO_TESTS)

trace-all: trace-build ## Run every miniRV Trace case in the pinned framework.
	@$(ROOT)/scripts/run-trace-suite.sh '$(TRACE_DIR)' $(TRACE_TESTS)

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
		$(MAKE) check PRODUCT="$$product"; \
	 done

clean: trace-clean ## Remove local WSL build outputs.
	@rm -rf '$(ROOT)/.cache'
