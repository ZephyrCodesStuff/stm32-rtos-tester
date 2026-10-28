# Set the minimum version of CMake that can be used
cmake_minimum_required(VERSION 3.20)

# Enable compile command to ease indexing with e.g. clangd
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)
set(CMAKE_C_COMPILER_FORCED TRUE)
set(CMAKE_CXX_COMPILER_FORCED TRUE)

# Target Board selection (from boards/<TARGET_BOARD>)
set(TARGET_BOARD "STM32F401RE" CACHE STRING "Target board configuration (from boards/<TARGET_BOARD>)")

# Load Board Configuration (supports exact name e.g. STM32F401RE or substring e.g. f401)
set(BOARD_DIR "${CMAKE_CURRENT_SOURCE_DIR}/boards/${TARGET_BOARD}")
if(NOT EXISTS "${BOARD_DIR}/board.cmake")
    file(GLOB _CANDIDATES "${CMAKE_CURRENT_SOURCE_DIR}/boards/*${TARGET_BOARD}*")
    list(LENGTH _CANDIDATES _NUM_CANDIDATES)
    if(_NUM_CANDIDATES GREATER 0)
        list(GET _CANDIDATES 0 _FOUND_DIR)
        set(BOARD_DIR "${_FOUND_DIR}")
        get_filename_component(TARGET_BOARD "${_FOUND_DIR}" NAME)
    else()
        message(FATAL_ERROR "Board configuration not found for '${TARGET_BOARD}' in 'boards/'.")
    endif()
endif()
include(${BOARD_DIR}/board.cmake)

# Linker script and startup file defaults for the active board
set(BOARD_LINKER_SCRIPT "${BOARD_DIR}/flash.ld")

# Set target definition variables required by starm-clang.cmake
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/target.cmake)

# Auto-detect ninja build tool across Linux (apt / ST bundles) and macOS (brew / ST bundles)
file(GLOB _CUBE_NINJA_DIRS
  "$ENV{HOME}/Library/Application Support/stm32cube/bundles/ninja/*/bin"
  "$ENV{HOME}/.local/stm32cube/bundles/ninja/*/bin"
  "$ENV{HOME}/.local/share/stm32cube/bundles/ninja/*/bin"
  "$ENV{HOME}/.stm32cube/bundles/ninja/*/bin"
)
if(NOT CMAKE_MAKE_PROGRAM)
  find_program(NINJA_EXECUTABLE NAMES ninja ninja-build
    PATHS
      ${_CUBE_NINJA_DIRS}
      "/opt/homebrew/bin"
      "/usr/local/bin"
      "/usr/bin"
  )
  if(NINJA_EXECUTABLE)
    set(CMAKE_MAKE_PROGRAM "${NINJA_EXECUTABLE}" CACHE FILEPATH "Path to ninja build tool" FORCE)
  endif()
endif()

# Auto-detect st-arm-clang compiler toolchain across Linux and macOS bundles
file(GLOB _CUBE_CLANG_DIRS
  "$ENV{HOME}/Library/Application Support/stm32cube/bundles/st-arm-clang/*/bin"
  "$ENV{HOME}/.local/stm32cube/bundles/st-arm-clang/*/bin"
  "$ENV{HOME}/.local/share/stm32cube/bundles/st-arm-clang/*/bin"
  "$ENV{HOME}/.stm32cube/bundles/st-arm-clang/*/bin"
)
find_program(STARM_CLANG_EXE NAMES starm-clang
  PATHS ${_CUBE_CLANG_DIRS}
)
if(STARM_CLANG_EXE)
  get_filename_component(_STARM_BIN_DIR "${STARM_CLANG_EXE}" DIRECTORY)
  set(ENV{PATH} "${_STARM_BIN_DIR}:$ENV{PATH}")
  list(PREPEND CMAKE_PROGRAM_PATH "${_STARM_BIN_DIR}")
endif()

# Set the toolchain file for cross-compilation
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/starm-clang.cmake)

# Project definition
project(lab-calculator)

# Enable CMake support for ASM and C/CPP languages
enable_language(C CXX ASM)

set(PROJECT_NAME lab-calculator)

# Create an executable object type
add_executable(${PROJECT_NAME})

# Optional CMSIS-RTOS v2 wrapper (CubeMX compatibility: osEventFlagsWait, osThreadNew, etc.)
option(ENABLE_CMSIS_OS2 "Enable CMSIS-RTOS v2 API wrapper over FreeRTOS" ON)

# Include flags, HAL components, FreeRTOS, and files
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/flags.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/components.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/hal.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/files.cmake)

if(ENABLE_CMSIS_OS2)
  include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/freertos-cmsis.cmake)
else()
  include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/freertos.cmake)
endif()

# Add board-specific include directory (for stm32..._hal_conf.h)
target_include_directories(${PROJECT_NAME} PRIVATE
  "${BOARD_DIR}"
)

# Add additional linker libraries
target_link_libraries(${PROJECT_NAME} PRIVATE
  # Unified Hardware Abstraction Library for STM32
  stm32_hal

  # FreeRTOS Kernel (or CMSIS-RTOS2 wrapper)
  $<$<BOOL:${ENABLE_CMSIS_OS2}>:cmsis_os2>
  $<$<NOT:$<BOOL:${ENABLE_CMSIS_OS2}>>:freertos_kernel>
)

# Generate flashable binary (.bin) and Intel HEX (.hex) artifacts
if(CMAKE_OBJCOPY)
  add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${PROJECT_NAME}> $<TARGET_FILE_DIR:${PROJECT_NAME}>/${PROJECT_NAME}.bin
    COMMAND ${CMAKE_OBJCOPY} -O ihex $<TARGET_FILE:${PROJECT_NAME}> $<TARGET_FILE_DIR:${PROJECT_NAME}>/${PROJECT_NAME}.hex
    COMMENT "Generating flash artifacts: ${PROJECT_NAME}.bin and ${PROJECT_NAME}.hex"
  )
endif()

# Export board runtime parameters for tooling (e.g. just flash, probe-rs, openocd)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/board.env"
"BOARD_NAME=\"${BOARD_NAME}\"
MCU_MODEL=\"${MCU_MODEL}\"
PROBE_CHIP=\"${PROBE_CHIP}\"
OPENOCD_TARGET=\"${OPENOCD_TARGET}\"
ELF_FILE=\"${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.elf\"
"
)

# Automatically update build/compile_commands.json for clangd on every build
add_custom_target(sync_compile_commands ALL
  COMMAND ${CMAKE_COMMAND} -E create_symlink
    "${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json"
    "${CMAKE_CURRENT_SOURCE_DIR}/build/compile_commands.json"
  COMMENT "Linking active compile_commands.json for target ${TARGET_BOARD}..."
)
