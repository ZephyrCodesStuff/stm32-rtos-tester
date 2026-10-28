#ifndef CALCULATOR_H
#define CALCULATOR_H

#include <stdint.h>

#define PACKET_SIZE sizeof(packet_t)

// Supported operands
typedef enum {
    CALC_OPERAND_ADD = 0,
    CALC_OPERAND_SUB,
    CALC_OPERAND_MUL,
    CALC_OPERAND_DIV,
} operand_t;

typedef struct __attribute__((packed)) {
    int32_t opcode;
    int32_t op1;
    int32_t op2;
} packet_t;

#endif // CALCULATOR_H
