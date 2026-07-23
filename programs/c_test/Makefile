SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

TEST ?= 0_uart_test
USE_DDR ?= 0
COREMARK_ARCH ?= im
COREMARK_ITERATIONS ?= 700

TESTS := \
	0_uart_test \
	1_formatIO_test \
	2_sort_test \
	3_ddr_test \
	4_coremark \
	5_llama2.c

BUILD_ROOT := $(CURDIR)/build

.PHONY: help list build clean

help: ## Show the C_TEST build entry points.
	@printf '%s\n' \
		'Usage: make build TEST=<name> [USE_DDR=0|1]' \
		'' \
		'Targets:' \
		'  list   List imported tests.' \
		'  build  Stage and build one test under build/<name>/.' \
		'  clean  Remove the generated build tree.'

list: ## List imported C_TEST programs.
	@printf '%s\n' $(TESTS)

build: ## Stage and build one C_TEST without modifying its source directory.
	@case ' $(TESTS) ' in \
		*' $(TEST) '*) ;; \
		*) printf 'Unknown TEST: %s\n' '$(TEST)' >&2; exit 2 ;; \
	esac
	@case '$(USE_DDR)' in 0|1) ;; *) printf 'USE_DDR must be 0 or 1\n' >&2; exit 2 ;; esac
	@source_dir='$(CURDIR)/$(TEST)'; \
	build_dir='$(BUILD_ROOT)/$(TEST)'; \
	rm -rf "$$build_dir"; \
	mkdir -p "$$build_dir"; \
	cp -a "$$source_dir/." "$$build_dir/"; \
	case '$(TEST)' in \
		0_uart_test|1_formatIO_test|2_sort_test) \
			if [[ '$(USE_DDR)' == 1 ]]; then script=compile_use_ddr.sh; else script=compile.sh; fi; \
			(cd "$$build_dir" && "./$$script") ;; \
		3_ddr_test) \
			(cd "$$build_dir" && ./compile.sh) ;; \
		4_coremark) \
			$(MAKE) -C "$$build_dir" coremark \
				ARCH='$(COREMARK_ARCH)' ITERATIONS='$(COREMARK_ITERATIONS)' ;; \
		5_llama2.c) \
			(cd "$$build_dir" && ./compile_use_ddr.sh) ;; \
	esac
	@printf 'Generated files are under %s/%s\n' '$(BUILD_ROOT)' '$(TEST)'

clean: ## Remove generated C_TEST build outputs.
	@rm -rf '$(BUILD_ROOT)'
