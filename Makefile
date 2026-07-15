SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
-include $(ROOT)/local.mk

PRODUCT ?= single_cycle
PROJECT_DIR := $(ROOT)/projects/$(PRODUCT)
RTL_DIR := $(PROJECT_DIR)/src/rtl
TRACE_DIR := $(ROOT)/cdp-tests
RTL_SOURCES := $(sort $(wildcard $(RTL_DIR)/*.v))
TRACE_VSRC := $(TRACE_DIR)/vsrc/bram_axi.v $(TRACE_DIR)/vsrc/ram.v $(RTL_SOURCES)
TRACE_SIM_OPTS := --trace -Wno-lint -Wno-style -Wno-TIMESCALEMOD -I$(RTL_DIR)
# start.bin is the board/MMIO demo rather than an instruction difftest case.
TRACE_TESTS := $(filter-out start,$(sort $(basename $(notdir $(wildcard $(TRACE_DIR)/bin/*.bin)))))
DEMO_TESTS := addi ori slli lw beq bne jal
LINT_WAIVER := $(ROOT)/config/verilator-$(PRODUCT).vlt

CCACHE_DIR ?= $(ROOT)/.cache/ccache
VIVADO_JOBS ?= 8

export CCACHE_DIR
export VIVADO_BIN
export VIVADO_STAGE_ROOT
export VIVADO_JOBS

.PHONY: help doctor status lint trace-build trace trace-demo trace-all \
	trace-clean vivado-stage vivado-synth vivado-bitstream \
	export-submission check clean

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

trace-all: trace-build ## Run every miniRV instruction Trace case in the pinned framework.
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

check: lint trace-demo ## Run the current pre-commit baseline checks.
	@git diff --check

clean: trace-clean ## Remove local WSL build outputs.
	@rm -rf '$(ROOT)/.cache'
