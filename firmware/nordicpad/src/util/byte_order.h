#ifndef UTIL_BYTE_ORDER_H
#define UTIL_BYTE_ORDER_H

#include <stddef.h>
#include <stdint.h>

void byte_order_reverse(uint8_t *destination, const uint8_t *source, size_t length);
void byte_order_xor(uint8_t *destination, const uint8_t *left, const uint8_t *right, size_t length);

#endif
