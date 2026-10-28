include(FetchContent)

# Set shallow clone to avoid downloading full git histories
set(FETCHCONTENT_QUIET FALSE)

# 1. ARM CMSIS Core (Common to ARM Cortex-M)
FetchContent_Declare(
    cmsis_core
    GIT_REPOSITORY https://github.com/STMicroelectronics/cmsis_core.git
    GIT_TAG        v5.6.0
    GIT_SHALLOW    TRUE
)

# 2. Family-specific CMSIS Device
FetchContent_Declare(
    cmsis_device
    GIT_REPOSITORY https://github.com/STMicroelectronics/cmsis_device_${MCU_FAMILY}.git
    GIT_TAG        ${CMSIS_DEVICE_TAG}
    GIT_SHALLOW    TRUE
)

# 3. Family-specific HAL Driver
FetchContent_Declare(
    hal_driver
    GIT_REPOSITORY https://github.com/STMicroelectronics/stm32${MCU_FAMILY}xx_hal_driver.git
    GIT_TAG        ${HAL_DRIVER_TAG}
    GIT_SHALLOW    TRUE
)

FetchContent_MakeAvailable(cmsis_core cmsis_device hal_driver)

# Discover family HAL sources
set(HAL_SOURCES
    ${cmsis_device_SOURCE_DIR}/Source/Templates/system_stm32${MCU_FAMILY}xx.c
    ${hal_driver_SOURCE_DIR}/Src/stm32${MCU_FAMILY}xx_hal.c
    ${hal_driver_SOURCE_DIR}/Src/stm32${MCU_FAMILY}xx_hal_cortex.c
    ${hal_driver_SOURCE_DIR}/Src/stm32${MCU_FAMILY}xx_hal_dma.c
    ${hal_driver_SOURCE_DIR}/Src/stm32${MCU_FAMILY}xx_hal_gpio.c
    ${hal_driver_SOURCE_DIR}/Src/stm32${MCU_FAMILY}xx_hal_pwr.c
    ${hal_driver_SOURCE_DIR}/Src/stm32${MCU_FAMILY}xx_hal_pwr_ex.c
    ${hal_driver_SOURCE_DIR}/Src/stm32${MCU_FAMILY}xx_hal_rcc.c
    ${hal_driver_SOURCE_DIR}/Src/stm32${MCU_FAMILY}xx_hal_rcc_ex.c
    ${hal_driver_SOURCE_DIR}/Src/stm32${MCU_FAMILY}xx_hal_uart.c
)

# 4. Create the unified HAL library
add_library(stm32_hal STATIC
    ${HAL_SOURCES}
)

# Alias for backwards compatibility
add_library(stm32f4_hal ALIAS stm32_hal)

target_include_directories(stm32_hal PUBLIC
    ${cmsis_core_SOURCE_DIR}/Include
    ${cmsis_device_SOURCE_DIR}/Include
    ${hal_driver_SOURCE_DIR}/Inc
    ${BOARD_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/Inc
)

target_compile_options(stm32_hal PUBLIC
    ${CPU_FLAGS}
    -Wno-comment
)

target_compile_definitions(stm32_hal PUBLIC
    ${MCU_DEF}
    BOARD_${BOARD_NAME}
    USE_HAL_DRIVER
    STM32_HAL_HEADER="stm32${MCU_FAMILY}xx_hal.h"
)
