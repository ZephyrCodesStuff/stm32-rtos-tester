set dotenv-load := true

# Auto-detect STM32Cube bundle path
_cube_dir := if os() == "macos" {
    env_var_or_default("HOME", "") + "/Library/Application Support/stm32cube/bundles"
} else {
    env_var_or_default("HOME", "") + "/.local/stm32cube/bundles"
}

# Dynamically find bundle bin directories with fallbacks
_ninja_bin := `find "$HOME/Library/Application Support/stm32cube/bundles/ninja" "$HOME/.local/stm32cube/bundles/ninja" "$HOME/.local/share/stm32cube/bundles/ninja" -type d -name "bin" 2>/dev/null | head -n 1 || true`
_clang_bin := `find "$HOME/Library/Application Support/stm32cube/bundles/st-arm-clang" "$HOME/.local/stm32cube/bundles/st-arm-clang" "$HOME/.local/share/stm32cube/bundles/st-arm-clang" -type d -name "bin" 2>/dev/null | head -n 1 || true`

export PATH := env_var_or_default("PATH", "") + ":" + _ninja_bin + ":" + _clang_bin + ":" + _cube_dir + "/ninja/1.13.2+st.1/bin:" + _cube_dir + "/st-arm-clang/21.1.1+st.7/bin:" + env_var_or_default("HOME", "") + "/.local/stm32cube/bin"

# Default recipe: list all available commands
default:
    @just --list

# Target selection (defaults to STM32F401RE Debug)
target := "f401"
build_type := "Debug"
cmsis := "true"

# List all available boards
boards:
    @echo "Available boards in boards/:"
    @ls -1 boards

# Configure CMake
configure target=target build_type=build_type cmsis=cmsis:
    #!/usr/bin/env bash
    set -euo pipefail
    BOARD=$(./scripts/resolve-board.sh "{{target}}")
    BUILD_DIR="build/${BOARD}-{{build_type}}"
    ENABLE_CMSIS="{{if cmsis == "true" { "ON" } else { "OFF" }}}"
    echo "Configuring ${BOARD} ({{build_type}})..."
    cmake -B "${BUILD_DIR}" -G Ninja \
        -DCMAKE_BUILD_TYPE="{{build_type}}" \
        -DTARGET_BOARD="${BOARD}" \
        -DENABLE_CMSIS_OS2="${ENABLE_CMSIS}"
    ln -sfn "${BOARD}-{{build_type}}/compile_commands.json" "build/compile_commands.json" 2>/dev/null || true

# Build firmware binary, auto-configuring if needed
build target=target build_type=build_type cmsis=cmsis:
    #!/usr/bin/env bash
    set -euo pipefail
    BOARD=$(./scripts/resolve-board.sh "{{target}}")
    BUILD_DIR="build/${BOARD}-{{build_type}}"
    ENABLE_CMSIS="{{if cmsis == "true" { "ON" } else { "OFF" }}}"
    CACHE="${BUILD_DIR}/CMakeCache.txt"
    if [ ! -f "${BUILD_DIR}/build.ninja" ] || ! grep -q "ENABLE_CMSIS_OS2:BOOL=${ENABLE_CMSIS}" "$CACHE" 2>/dev/null; then
        echo "Configuring ${BOARD} ({{build_type}})..."
        cmake -B "${BUILD_DIR}" -G Ninja \
            -DCMAKE_BUILD_TYPE="{{build_type}}" \
            -DTARGET_BOARD="${BOARD}" \
            -DENABLE_CMSIS_OS2="${ENABLE_CMSIS}"
    fi
    ln -sfn "${BOARD}-{{build_type}}/compile_commands.json" "build/compile_commands.json" 2>/dev/null || true
    cmake --build "${BUILD_DIR}"

# Flash firmware to the microcontroller (sources board parameters dynamically)
flash target=target build_type=build_type cmsis=cmsis: (build target build_type cmsis)
    #!/usr/bin/env bash
    set -euo pipefail
    BOARD=$(./scripts/resolve-board.sh "{{target}}")
    ENV_FILE="build/${BOARD}-{{build_type}}/board.env"
    if [ ! -f "$ENV_FILE" ]; then
        echo "Error: $ENV_FILE not found. Run 'just build' first."
        exit 1
    fi
    source "$ENV_FILE"
    echo "Flashing $PROBE_CHIP with $ELF_FILE..."
    if command -v probe-rs >/dev/null 2>&1; then
        probe-rs download --chip "$PROBE_CHIP" "$ELF_FILE" && probe-rs reset --chip "$PROBE_CHIP"
    elif command -v openocd >/dev/null 2>&1; then
        openocd -f interface/stlink.cfg -f "$OPENOCD_TARGET" -c "program $ELF_FILE verify reset exit"
    elif command -v STM32_Programmer_CLI >/dev/null 2>&1; then
        STM32_Programmer_CLI -c port=SWD -w "$ELF_FILE" -v -rst
    else
        echo "Error: No supported flasher found (probe-rs, openocd, or STM32_Programmer_CLI)."
        exit 1
    fi

# Flash and stream live logs / RTT output
run target=target build_type=build_type cmsis=cmsis: (build target build_type cmsis)
    #!/usr/bin/env bash
    BOARD=$(./scripts/resolve-board.sh "{{target}}")
    source "build/${BOARD}-{{build_type}}/board.env"
    probe-rs run --chip "$PROBE_CHIP" "$ELF_FILE"

# Hard reset connected microcontroller
reset target=target build_type=build_type:
    #!/usr/bin/env bash
    BOARD=$(./scripts/resolve-board.sh "{{target}}")
    source "build/${BOARD}-{{build_type}}/board.env"
    if command -v probe-rs >/dev/null 2>&1; then
        probe-rs reset --chip "$PROBE_CHIP"
    elif command -v openocd >/dev/null 2>&1; then
        openocd -f interface/stlink.cfg -f "$OPENOCD_TARGET" -c "init; reset; exit"
    fi

# Show memory footprint of binary
size target=target build_type=build_type:
    #!/usr/bin/env bash
    BOARD=$(./scripts/resolve-board.sh "{{target}}")
    ELF="build/${BOARD}-{{build_type}}/lab-calculator.elf"
    if [ ! -f "$ELF" ]; then
        echo "Binary not found at $ELF. Run 'just target={{target}} build' first."
        exit 1
    fi
    if command -v starm-size >/dev/null 2>&1; then
        starm-size "$ELF"
    elif command -v arm-none-eabi-size >/dev/null 2>&1; then
        arm-none-eabi-size "$ELF"
    elif command -v llvm-size >/dev/null 2>&1; then
        llvm-size "$ELF"
    else
        size "$ELF"
    fi

# Run clang-tidy static analysis on application source files, auto-configuring if needed
lint target=target build_type=build_type cmsis=cmsis:
    #!/usr/bin/env bash
    set -euo pipefail
    BOARD=$(./scripts/resolve-board.sh "{{target}}")
    BUILD_DIR="build/${BOARD}-{{build_type}}"
    ENABLE_CMSIS="{{if cmsis == "true" { "ON" } else { "OFF" }}}"
    CACHE="${BUILD_DIR}/CMakeCache.txt"
    if ! command -v clang-tidy >/dev/null 2>&1; then
        echo "Error: clang-tidy is required for linting but was not found." >&2
        exit 1
    fi
    if [ ! -f "${BUILD_DIR}/compile_commands.json" ] || ! grep -q "ENABLE_CMSIS_OS2:BOOL=${ENABLE_CMSIS}" "$CACHE" 2>/dev/null; then
        echo "Configuring ${BOARD} ({{build_type}})..."
        cmake -B "${BUILD_DIR}" -G Ninja \
            -DCMAKE_BUILD_TYPE="{{build_type}}" \
            -DTARGET_BOARD="${BOARD}" \
            -DENABLE_CMSIS_OS2="${ENABLE_CMSIS}"
    fi
    ln -sfn "${BOARD}-{{build_type}}/compile_commands.json" "build/compile_commands.json" 2>/dev/null || true
    FILES=$(find Src -name "*.c" ! -name "sys*.c")
    echo "Running static analysis on: $FILES (${BOARD})"
    clang-tidy $FILES -p "$BUILD_DIR" --extra-arg=--sysroot=/dummy --quiet --warnings-as-errors='*'

# Clean build artifacts (specify target to clean one board, or 'all')
clean target="all":
    #!/usr/bin/env bash
    if [ "{{target}}" != "all" ] && [ -n "{{target}}" ]; then
        BOARD=$(./scripts/resolve-board.sh "{{target}}")
        rm -rf "build/${BOARD}-"*
        echo "Cleaned build artifacts for ${BOARD}"
    else
        rm -rf build/
        echo "Cleaned all build directories"
    fi

# Clean and rebuild from scratch
rebuild target=target build_type=build_type cmsis=cmsis: (clean target) (build target build_type cmsis)

# Run Renode automated tests (Robot Framework)
test target=target build_type=build_type cmsis=cmsis: (build target build_type cmsis)
    #!/usr/bin/env bash
    set -euo pipefail
    renode-test test/calculator.robot

