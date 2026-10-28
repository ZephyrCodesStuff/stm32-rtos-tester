/**
  ******************************************************************************
  * @file    stm32g4xx_hal_conf.h
  * @brief   HAL configuration file for STM32G4xx devices.
  ******************************************************************************
  */

#ifndef STM32G4xx_HAL_CONF_H
#define STM32G4xx_HAL_CONF_H

#ifdef __cplusplus
 extern "C" {
#endif

/* ########################## Module Selection ############################## */
#define HAL_MODULE_ENABLED
#define HAL_CORTEX_MODULE_ENABLED
#define HAL_DMA_MODULE_ENABLED
#define HAL_FLASH_MODULE_ENABLED
#define HAL_GPIO_MODULE_ENABLED
#define HAL_PWR_MODULE_ENABLED
#define HAL_RCC_MODULE_ENABLED
#define HAL_UART_MODULE_ENABLED
#define HAL_EXTI_MODULE_ENABLED

/* ########################## Oscillator Values ############################# */
#if !defined  (HSE_VALUE)
  #define HSE_VALUE    24000000U /*!< Value of the External oscillator in Hz */
#endif

#if !defined  (HSE_STARTUP_TIMEOUT)
  #define HSE_STARTUP_TIMEOUT    100U
#endif

#if !defined  (HSI_VALUE)
  #define HSI_VALUE    16000000U /*!< Value of the Internal oscillator in Hz*/
#endif

#if !defined  (LSI_VALUE)
  #define LSI_VALUE  32000U
#endif

#if !defined  (LSE_VALUE)
  #define LSE_VALUE    32768U
#endif

#if !defined  (LSE_STARTUP_TIMEOUT)
  #define LSE_STARTUP_TIMEOUT    5000U
#endif

#if !defined  (EXTERNAL_CLOCK_VALUE)
  #define EXTERNAL_CLOCK_VALUE   48000U /*!< Value of the External clock source in Hz */
#endif

#if !defined  (HSI48_VALUE)
  #define HSI48_VALUE            48000000U /*!< Value of the Internal High Speed oscillator for USB FS/RNG in Hz */
#endif

/* ########################### System Configuration ######################### */
#define  VDD_VALUE                    3300U /*!< Value of VDD in mv */
#define  TICK_INT_PRIORITY            0x0FU /*!< tick interrupt priority */
#define  USE_RTOS                     0U
#define  PREFETCH_ENABLE              0U
#define  INSTRUCTION_CACHE_ENABLE     1U
#define  DATA_CACHE_ENABLE            1U

/* ########################## Includes ###################################### */
#ifdef HAL_RCC_MODULE_ENABLED
  #include "stm32g4xx_hal_rcc.h"
#endif

#ifdef HAL_GPIO_MODULE_ENABLED
  #include "stm32g4xx_hal_gpio.h"
#endif

#ifdef HAL_DMA_MODULE_ENABLED
  #include "stm32g4xx_hal_dma.h"
#endif

#ifdef HAL_CORTEX_MODULE_ENABLED
  #include "stm32g4xx_hal_cortex.h"
#endif

#ifdef HAL_FLASH_MODULE_ENABLED
  #include "stm32g4xx_hal_flash.h"
#endif

#ifdef HAL_PWR_MODULE_ENABLED
  #include "stm32g4xx_hal_pwr.h"
#endif

#ifdef HAL_UART_MODULE_ENABLED
  #include "stm32g4xx_hal_uart.h"
#endif

#ifdef HAL_EXTI_MODULE_ENABLED
  #include "stm32g4xx_hal_exti.h"
#endif

/* ########################## Assert Selection ############################## */
#ifdef  USE_FULL_ASSERT
  #define assert_param(expr) ((expr) ? (void)0U : assert_failed((uint8_t *)__FILE__, __LINE__))
  void assert_failed(uint8_t *file, uint32_t line);
#else
  #define assert_param(expr) ((void)0U)
#endif

#ifdef __cplusplus
}
#endif

#endif /* STM32G4xx_HAL_CONF_H */
