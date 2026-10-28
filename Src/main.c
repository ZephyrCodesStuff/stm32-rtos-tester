/*

    ###################################
    # Laboratory: UART Calculator
    # Author: [zeph](https://github.com/ZephyrCodesStuff)
    ###################################

    This module is designed to provide a hands-on experience
    with FreeRTOS on an STM32F4 microcontroller.

    Your goal is to implement a simple UART listener, such that
    the board can act as a calculator.

    (Optional) For concurrency support, your implementation should
    not stall a secondary task while reading and handling operations.

    The secondary task should be a simple LED blinker that toggles an LED every 500ms.

    The packet format to expect is:
    [OPERATOR][OPERAND1][OPERAND2] (9 bytes packed)

    The packet format for responses is:
    [RESULT] (4 bytes)

    Where:
    - [OPERATOR] is a single byte representing the operation to perform.
      Supported operators are:
        - 0 for addition
        - 1 for subtraction
        - 2 for multiplication
        - 3 for division
    - [OPERAND1] and [OPERAND2] are 32-bit signed integers (little-endian format).
    - [RESULT] is a 32-bit signed integer (little-endian format)

    ---

    Enjoy your lab!
    - zeph
*/

#include "FreeRTOS.h"
#include "cmsis_os2.h"
#include "stm32_hal.h"
#include "task.h"

#include "calculator.h"

// Global configuration for USART2 in asynchronous UART mode
static UART_HandleTypeDef g_uart2 = {
    .Instance = USART2,
    .Init =
        {
            .BaudRate = 115200,
            .WordLength = UART_WORDLENGTH_8B,
            .StopBits = UART_STOPBITS_1,
            .Parity = UART_PARITY_NONE,
            .Mode = UART_MODE_TX_RX,
            .HwFlowCtl = UART_HWCONTROL_NONE,
            .OverSampling = UART_OVERSAMPLING_16,
        },
};

// Storage for UART2 received data
static packet_t g_uart2_buf;
// Storage for UART2 responses
static uint32_t g_uart2_res;

/* FreeRTOS calls this every 1ms SysTick interrupt */
// NOLINTNEXTLINE(misc-use-internal-linkage)
void vApplicationTickHook( void )
{ HAL_IncTick(); }

static void TASK_BlinkLED( void* pvParameters )
{
    UNUSED( pvParameters );

    while ( 1 )
    {
        HAL_GPIO_TogglePin( GPIOA, GPIO_PIN_5 );  // Toggle LED
        osDelay( 500 );                           // Delay for 500ms
    }
}

static void TASK_ReceiveUSART2( void* pvParameters )
{
    UNUSED( pvParameters );

    // Start non-blocking reception for the first packet
    HAL_UART_Receive_IT( &g_uart2, (uint8_t*)&g_uart2_buf, PACKET_SIZE );

    while ( 1 )
    {
        // Yield CPU; interrupt callback processes packets asynchronously
        osDelay( 1000 );
    }
}

// NOLINTNEXTLINE(misc-use-internal-linkage)
void USART2_IRQHandler( void )
{ HAL_UART_IRQHandler( &g_uart2 ); }

// Handle UART receive finished
// NOLINTNEXTLINE(misc-use-internal-linkage)
void HAL_UART_RxCpltCallback( UART_HandleTypeDef* huart )
{
    // Assert this callback is for USART2
    if ( huart->Instance != g_uart2.Instance )
    {
        return;
    }

    switch ( g_uart2_buf.opcode )
    {
        case CALC_OPERAND_ADD: {
            g_uart2_res = g_uart2_buf.op1 + g_uart2_buf.op2;
            break;
        }

        case CALC_OPERAND_SUB: {
            g_uart2_res = g_uart2_buf.op1 - g_uart2_buf.op2;
            break;
        }

        case CALC_OPERAND_MUL: {
            g_uart2_res = g_uart2_buf.op1 * g_uart2_buf.op2;
            break;
        }

        case CALC_OPERAND_DIV: {
            if ( g_uart2_buf.op2 != 0 )
            {
                g_uart2_res = g_uart2_buf.op1 / g_uart2_buf.op2;
            } else
            {
                g_uart2_res = 0xDEADBEEF;
            }
            break;
        }

        default: {
            g_uart2_res = 0xDEADBEEF;
            break;
        }
    }

    // Clean buffer
    g_uart2_buf.opcode = 0;
    g_uart2_buf.op1 = 0;
    g_uart2_buf.op2 = 0;

    // Transmit 4-byte response
    HAL_UART_Transmit_IT( &g_uart2, (uint8_t*)&g_uart2_res,
                          sizeof( g_uart2_res ) );

    // Re-arm reception for subsequent packets
    HAL_UART_Receive_IT( &g_uart2, (uint8_t*)&g_uart2_buf, PACKET_SIZE );
}

int main( void )
{
    HAL_Init();

    // ----------------------------------------
    // (Optional) LED Blinker

    __HAL_RCC_GPIOA_CLK_ENABLE();  // Enable GPIOA clock

    // Configure GPIOA Pin 5 as output for LED
    GPIO_InitTypeDef GPIO_InitStruct = { 0 };
    GPIO_InitStruct.Pin = GPIO_PIN_5;
    GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
    GPIO_InitStruct.Pull = GPIO_NOPULL;
    GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init( GPIOA, &GPIO_InitStruct );

    // Start the LED blink task
    osThreadNew( TASK_BlinkLED, NULL, NULL );

    // ----------------------------------------
    // USART2 Pins and Peripherals

    // Configure GPIOA Pin 2 (TX) and Pin 3 (RX) for USART2 AF7
    GPIO_InitTypeDef GPIO_UartStruct = { 0 };
    GPIO_UartStruct.Pin = GPIO_PIN_2 | GPIO_PIN_3;
    GPIO_UartStruct.Mode = GPIO_MODE_AF_PP;
    GPIO_UartStruct.Pull = GPIO_PULLUP;
    GPIO_UartStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
    GPIO_UartStruct.Alternate = GPIO_AF7_USART2;
    HAL_GPIO_Init( GPIOA, &GPIO_UartStruct );

    // Ensure UART buffer is empty
    g_uart2_buf.opcode = 0;
    g_uart2_buf.op1 = 0;
    g_uart2_buf.op2 = 0;

    // Enable USART2 clock and init UART
    __HAL_RCC_USART2_CLK_ENABLE();
    HAL_UART_Init( &g_uart2 );

    // Configure NVIC for USART2 interrupt
    HAL_NVIC_SetPriority( USART2_IRQn, 5, 0 );
    HAL_NVIC_EnableIRQ( USART2_IRQn );

    // Start the USART2 task
    osThreadNew( TASK_ReceiveUSART2, NULL, NULL );

    // ----------------------------------------

    uint32_t res = osEventFlagsWait( NULL, 0x01, osFlagsWaitAny, 0 );
    UNUSED( res );

    vTaskStartScheduler();

    while ( 1 ) {}
}
