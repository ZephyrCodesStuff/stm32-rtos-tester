*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}
Library                       OperatingSystem

*** Variables ***
${PLATFORM}                   @${CURDIR}/stm32f401re.repl
${ELF_PATH}                   @${CURDIR}/../build/STM32F401RE-Debug/lab-calculator.elf

*** Keywords ***
Create Calculator Machine
    [Arguments]               ${out_file}    ${elf}=${ELF_PATH}
    Execute Command           mach create "stm32f401re"
    Execute Command           machine LoadPlatformDescription ${PLATFORM}
    Execute Command           sysbus LoadELF ${elf}
    Remove File               ${out_file}
    Execute Command           sysbus.usart2 CreateFileBackend @${out_file} true

Send Byte
    [Arguments]               ${byte}
    Execute Command           sysbus.usart2 WriteChar ${byte}

Send Int32 LittleEndian
    [Arguments]               ${val}
    ${b0}=                    Evaluate    (${val} & 0xFF)
    ${b1}=                    Evaluate    ((${val} >> 8) & 0xFF)
    ${b2}=                    Evaluate    ((${val} >> 16) & 0xFF)
    ${b3}=                    Evaluate    ((${val} >> 24) & 0xFF)
    Send Byte                 ${b0}
    Send Byte                 ${b1}
    Send Byte                 ${b2}
    Send Byte                 ${b3}

Send Calculator Request
    [Arguments]               ${opcode}    ${op1}    ${op2}
    Send Int32 LittleEndian   ${opcode}
    Send Int32 LittleEndian   ${op1}
    Send Int32 LittleEndian   ${op2}

Read Response From UART
    [Arguments]               ${out_file}
    # Close the file backend to ensure all C# streams and OS buffers are flushed to disk
    Execute Command           sysbus.usart2 CloseFileBackend @${out_file}
    ${content}=               Get Binary File    ${out_file}
    ${len}=                   Evaluate    len($content)
    Should Be True            ${len} >= 4    Expected at least 4 bytes from USART2, got ${len}
    ${result}=                Evaluate    __import__('struct').unpack('<i', $content[:4])[0]
    RETURN                    ${result}

Verify Result In Memory
    [Arguments]               ${expected}
    ${addr}=                  Execute Command    sysbus GetSymbolAddress "g_uart2_res"
    ${actual_hex}=            Execute Command    sysbus ReadDoubleWord ${addr}
    ${actual}=                Evaluate    int($actual_hex.strip(), 0)
    Should Be Equal As Integers    ${actual}    ${expected}

*** Test Cases ***
Should Perform Addition
    ${out_file}=              Set Variable    ${CURDIR}/usart2_add.bin
    Create Calculator Machine    ${out_file}
    Start Emulation
    Sleep                     0.05s

    # Send: ADD (opcode 0), 15 + 27 = 42
    Send Calculator Request   0    15    27
    Sleep                     0.05s

    ${uart_result}=           Read Response From UART    ${out_file}
    Should Be Equal As Integers    ${uart_result}    42
    Verify Result In Memory   42

Should Perform Subtraction
    ${out_file}=              Set Variable    ${CURDIR}/usart2_sub.bin
    Create Calculator Machine    ${out_file}
    Start Emulation
    Sleep                     0.05s

    # Send: SUB (opcode 1), 100 - 42 = 58
    Send Calculator Request   1    100    42
    Sleep                     0.05s

    ${uart_result}=           Read Response From UART    ${out_file}
    Should Be Equal As Integers    ${uart_result}    58
    Verify Result In Memory   58

Should Perform Multiplication
    ${out_file}=              Set Variable    ${CURDIR}/usart2_mul.bin
    Create Calculator Machine    ${out_file}
    Start Emulation
    Sleep                     0.05s

    # Send: MUL (opcode 2), 6 * 7 = 42
    Send Calculator Request   2    6    7
    Sleep                     0.05s

    ${uart_result}=           Read Response From UART    ${out_file}
    Should Be Equal As Integers    ${uart_result}    42
    Verify Result In Memory   42

Should Perform Division
    ${out_file}=              Set Variable    ${CURDIR}/usart2_div.bin
    Create Calculator Machine    ${out_file}
    Start Emulation
    Sleep                     0.05s

    # Send: DIV (opcode 3), 144 / 12 = 12
    Send Calculator Request   3    144    12
    Sleep                     0.05s

    ${uart_result}=           Read Response From UART    ${out_file}
    Should Be Equal As Integers    ${uart_result}    12
    Verify Result In Memory   12
