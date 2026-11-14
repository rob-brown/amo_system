#include "util/byte_order.h"

void byte_order_reverse(uint8_t *destination, const uint8_t *source, size_t length) {
    for (size_t index = 0; index < length / 2; index++) {
        uint8_t front = source[index];
        uint8_t back = source[length - 1 - index];
        destination[index] = back;
        destination[length - 1 - index] = front;
    }

    if (length % 2 == 1) {
        destination[length / 2] = source[length / 2];
    }
}

void byte_order_xor(uint8_t *destination, const uint8_t *left, const uint8_t *right, size_t length) {
    for (size_t index = 0; index < length; index++) {
        destination[index] = left[index] ^ right[index];
    }
}
