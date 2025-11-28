.PHONY: all run clean conan test test-rerun test-verbose lint check-format format sort-dictionary cleanup-dictionary check-cspell-ignored docker-dev-build docker-dev docker-make docker-test docker-publish-ci coverage coverage-clean coverage-report

# -----------------------------
# Build Configuration
# -----------------------------
# Default preset, override with `make BUILD_TYPE=Release`
BUILD_TYPE ?= Debug
CMAKE_PRESET := conan-$(shell echo $(BUILD_TYPE) | tr A-Z a-z)

# Coverage configuration
ENABLE_COVERAGE ?= OFF

TARGET := build/$(BUILD_TYPE)/bin/vhdl_formatter
CONAN_STAMP := build/.conan.$(BUILD_TYPE).stamp
BUILD_STAMP := build/.build.$(BUILD_TYPE).stamp

SOURCES := $(shell find src tests -type f \( -name '*.cpp' -o -name '*.hpp' \) ! -path "*/build/*")
SOURCES_CMAKE := $(shell find src tests . -name 'CMakeLists.txt')

# -----------------------------
# Build Targets
# -----------------------------
all: $(BUILD_STAMP)

$(BUILD_STAMP): $(SOURCES) $(SOURCES_CMAKE) $(CONAN_STAMP)
	@echo "Building project ($(BUILD_TYPE), Coverage=$(ENABLE_COVERAGE))..."
	@cmake --preset $(CMAKE_PRESET) -DENABLE_COVERAGE=$(ENABLE_COVERAGE)
	@cmake --build --preset $(CMAKE_PRESET)
	@touch $@
	@echo "Build complete."

CONAN_CMD := conan
$(CONAN_STAMP): conanfile.txt
	$(call check_tool,$(CONAN_CMD))
	@echo "Running Conan ($(BUILD_TYPE))..."
	@$(CONAN_CMD) install . \
		--profile:host=clang.profile \
		--profile:build=clang.profile \
		--build=missing \
		-s build_type=$(BUILD_TYPE)
	@touch $@

conan: $(CONAN_STAMP)

run: $(BUILD_STAMP)
	@./$(TARGET) ./tests/data/vhdl/simple.vhd

test: $(BUILD_STAMP)
	@ctest --preset $(CMAKE_PRESET) --output-on-failure -LE "benchmark"

test-rerun-failed: $(BUILD_STAMP)
	@ctest --preset $(CMAKE_PRESET) --rerun-failed --output-on-failure -LE "benchmark"

test-verbose: $(BUILD_STAMP)
	@ctest --preset $(CMAKE_PRESET) --verbose -LE "benchmark"

clean:
	@rm -rf build CMakeFiles CMakeCache.txt CMakeUserPresets.json .cache

# -----------------------------
# Coverage Targets
# -----------------------------
# Generate HTML coverage report
coverage:
	@$(MAKE) BUILD_TYPE=Debug ENABLE_COVERAGE=ON all
	@cmake --build build/Debug --target coverage
	@echo ""
	@echo "✓ HTML coverage report: build/Debug/coverage/html/index.html"

# Generate text coverage summary
coverage-report:
	@$(MAKE) BUILD_TYPE=Debug ENABLE_COVERAGE=ON all
	@cmake --build build/Debug --target coverage-report

# Open HTML coverage report in browser
coverage-show: coverage
	@xdg-open build/Debug/coverage/html/index.html 2>/dev/null || \
		open build/Debug/coverage/html/index.html 2>/dev/null || \
		echo "Please open build/Debug/coverage/html/index.html in your browser"

# Clean coverage data
coverage-clean:
	@cmake --build build/Debug --target coverage-clean 2>/dev/null || \
		rm -rf build/Debug/coverage

# -----------------------------
# Utility Targets
# -----------------------------
CLANG_TIDY_CMD := clang-tidy
RUN_CLANG_TIDY_CMD := run-clang-tidy
CLANG_FORMAT_CMD := clang-format
GERSEMI_CMD := gersemi

LINT_COMMON_FLAGS = -p build/$(BUILD_TYPE)/ -quiet
LINT_TIDY_FLAGS = -warnings-as-errors='*'
LINT_CPUS ?= $(shell nproc)

GERSEMI_FLAGS = --list-expansion=favour-expansion --no-warn-about-unknown-commands

# Function to check for tool existence
# Usage: $(call check_tool, tool_name)
define check_tool
@if ! command -v $(1) > /dev/null 2>&1; then \
	echo "Error: Required tool '$(1)' not found."; \
	echo "Please ensure it is installed and available in your PATH."; \
	exit 1; \
fi
endef

ifdef SOURCES_TO_LINT
	FILES_TO_LINT := $(SOURCES_TO_LINT)
else ifeq ($(LINT_FILES),source)
	FILES_TO_LINT := $(shell find src tests -name '*.cpp' ! -path "*/build/*")
else ifeq ($(LINT_FILES),header)
	FILES_TO_LINT := $(shell find src tests -name '*.hpp' ! -path "*/build/*")
else
	FILES_TO_LINT := $(SOURCES)
endif

# Use `make lint LINT_FILES=header/source` to lint either one
lint:
	$(call check_tool,$(RUN_CLANG_TIDY_CMD))
	$(call check_tool,$(CLANG_TIDY_CMD))
	@echo "Linting with $(LINT_CPUS) cores"
	@if [ -z "$(FILES_TO_LINT)" ]; then \
		echo "No files to lint (LINT_FILES='$(LINT_FILES)')."; \
		exit 0; \
	fi

	@if [ "$(LINT_FILES)" = "source" ] || [ -z "$(LINT_FILES)" ]; then \
		SOURCE_FILES="$$(echo '$(FILES_TO_LINT)' | tr ' ' '\n' | grep '\.cpp$$')"; \
		if [ -n "$$SOURCE_FILES" ]; then \
			echo "Running clang-tidy on source files..."; \
			echo "$$SOURCE_FILES" | xargs $(RUN_CLANG_TIDY_CMD) $(LINT_COMMON_FLAGS) $(LINT_TIDY_FLAGS) -j $(LINT_CPUS) || exit 1; \
		fi; \
	fi

	@if [ "$(LINT_FILES)" = "header" ] || [ -z "$(LINT_FILES)" ]; then \
		HEADER_FILES="$$(echo '$(FILES_TO_LINT)' | tr ' ' '\n' | grep '\.hpp$$')"; \
		if [ -n "$$HEADER_FILES" ]; then \
			echo "Running clang-tidy on headers..."; \
			echo "$$HEADER_FILES" | xargs -r -P $(LINT_CPUS) -n 1 $(CLANG_TIDY_CMD) $(LINT_COMMON_FLAGS) $(LINT_TIDY_FLAGS) || exit 1; \
		fi; \
	fi

	@echo "✓ Linting complete"

lint-diff:
	$(call check_tool,$(RUN_CLANG_TIDY_CMD))
	$(call check_tool,$(CLANG_TIDY_CMD))
	@echo "Linting changed files compared to main branch..."
	@CHANGED_FILES=$$(git diff --name-only --diff-filter=ACM main...HEAD | grep -E '\.(cpp|hpp)$$' || true); \
	if [ -z "$$CHANGED_FILES" ]; then \
		echo "No C++ files changed."; \
		exit 0; \
	fi; \
	echo "Files to lint: $$CHANGED_FILES"; \
	SOURCES=$$(echo "$$CHANGED_FILES" | grep '\.cpp$$' || true); \
	HEADERS=$$(echo "$$CHANGED_FILES" | grep '\.hpp$$' || true); \
	if [ -n "$$SOURCES" ]; then \
		echo "Running clang-tidy on changed source files..."; \
		$(RUN_CLANG_TIDY_CMD) $(LINT_COMMON_FLAGS) $(LINT_TIDY_FLAGS) -j $(LINT_CPUS) $$SOURCES || exit 1; \
	fi; \
	if [ -n "$$HEADERS" ]; then \
		echo "Running clang-tidy on changed headers..."; \
		echo "$$HEADERS" | xargs -r -P $(LINT_CPUS) -n 1 $(CLANG_TIDY_CMD) $(LINT_COMMON_FLAGS) $(LINT_TIDY_FLAGS) || exit 1; \
	fi; \
	echo "✓ Linting complete"

check-format:
	$(call check_tool,$(CLANG_FORMAT_CMD))
	$(call check_tool,$(GERSEMI_CMD))
	@echo "Checking code formatting..."
	@if $(CLANG_FORMAT_CMD) --dry-run --Werror $(SOURCES) && $(GERSEMI_CMD) --check --diff --color $(GERSEMI_FLAGS) $(SOURCES_CMAKE); then \
		echo "✓ All files are properly formatted"; \
	else \
		exit 1; \
	fi

format:
	$(call check_tool,$(CLANG_FORMAT_CMD))
	$(call check_tool,$(GERSEMI_CMD))
	@echo "Formatting code..."
	@$(CLANG_FORMAT_CMD) -i $(SOURCES)
	@$(GERSEMI_CMD) -i $(GERSEMI_FLAGS) $(SOURCES_CMAKE)
	@echo "✓ Code formatting complete"

sort-dictionary:
	@echo "Sorting dictionary..."
	@tr '[:upper:]' '[:lower:]' < .cspell_ignored | sort -f -u -o .cspell_ignored
	@echo "✓ Sorted and converted .cspell_ignored to lowercase with unique entries"

cleanup-dictionary:
	@echo "Cleaning up unused words from .cspell_ignored..."
	@.github/scripts/cleanup-cspell-ignored.sh

check-cspell-ignored:
	@echo "Checking for unused words in .cspell_ignored..."
	@.github/scripts/check-cspell-ignored.sh
	@echo "✓ Cspell ignored file check complete"

# -----------------------------
# Docker Development Environment
# -----------------------------
CONTAINER_CMD ?= docker
CI_IMAGE_NAME ?= ghcr.io/niekdomi/vhdl-fmt/vhdlfmt-ci:latest

docker-dev-build:
	@echo "Building development environment with $(CONTAINER_CMD)..."
	@$(CONTAINER_CMD) compose build

docker-dev:
	@echo "Starting development shell with $(CONTAINER_CMD)..."
	@$(CONTAINER_CMD) compose run --rm dev

docker-make:
	@echo "Building project in container..."
	@$(CONTAINER_CMD) compose run --rm dev bash -c "make clean && make"

docker-test:
	@echo "Building project in container..."
	@$(CONTAINER_CMD) compose run --rm dev bash -c "make clean && make test"

docker-coverage:
	@echo "Generating coverage in container..."
	@$(CONTAINER_CMD) compose run --rm dev bash -c "make coverage"

docker-publish-ci:
	@echo "Building and publishing CI image to $(CI_IMAGE_NAME)..."
	@$(CONTAINER_CMD) build . -t $(CI_IMAGE_NAME) --target ci
	@$(CONTAINER_CMD) push $(CI_IMAGE_NAME)
	@echo "✓ CI image published."

# -----------------------------
# Benchmark Targets
# -----------------------------
# Benchmarks must run in Release mode for accuracy.

BENCHMARK_BIN       := ./build/Release/bin/vhdl_benchmarks
BENCHMARK_RESULTS   := ./tests/benchmarks/.results
BENCHMARK_SCRIPT    := ./tests/benchmarks/compare_benchmarks.py
BENCHMARK_SAMPLES   := 200

BENCHMARK_CMD       := $(BENCHMARK_BIN) --benchmark-samples $(BENCHMARK_SAMPLES)
BENCHMARK_BASELINE  := $(BENCHMARK_RESULTS)/baseline.xml
BENCHMARK_CURRENT   := $(BENCHMARK_RESULTS)/new.xml

.PHONY: benchmark benchmark-build benchmark-baseline benchmark-compare benchmark-clean

benchmark-build:
	@echo "Preparing Release build for accurate benchmarking..."
	@$(MAKE) --no-print-directory BUILD_TYPE=Release

benchmark: benchmark-build
	@echo "Running Benchmarks (Samples: $(BENCHMARK_SAMPLES))..."
	@$(BENCHMARK_CMD)

benchmark-baseline: benchmark-build
	@echo "Creating baseline benchmark..."
	@mkdir -p $(BENCHMARK_RESULTS)
	@$(BENCHMARK_CMD) -r XML -o $(BENCHMARK_BASELINE)
	@echo "✓ Baseline saved to $(BENCHMARK_BASELINE)"

benchmark-compare: benchmark-build
	@echo "Running benchmarks to compare against baseline..."
	@mkdir -p $(BENCHMARK_RESULTS)
	@$(BENCHMARK_CMD) -r XML -o $(BENCHMARK_CURRENT)
	@echo "Comparing results..."
	@$(BENCHMARK_SCRIPT) $(BENCHMARK_BASELINE) $(BENCHMARK_CURRENT)

benchmark-clean:
	@echo "Cleaning benchmark results..."
	@rm -f $(BENCHMARK_BASELINE) $(BENCHMARK_CURRENT)
	@echo "✓ Done"
