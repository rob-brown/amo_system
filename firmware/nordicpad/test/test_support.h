#ifndef TEST_SUPPORT_H
#define TEST_SUPPORT_H

#include <stddef.h>
#include <stdint.h>

static inline int hex_digit_value(char digit) {
    if (digit >= '0' && digit <= '9') {
        return digit - '0';
    }
    if (digit >= 'a' && digit <= 'f') {
        return digit - 'a' + 10;
    }
    if (digit >= 'A' && digit <= 'F') {
        return digit - 'A' + 10;
    }
    return -1;
}

static inline size_t hex_decode(const char *hex, uint8_t *output, size_t capacity) {
    size_t count = 0;

    while (hex_digit_value(hex[0]) >= 0 && hex_digit_value(hex[1]) >= 0 && count < capacity) {
        output[count++] = (uint8_t)(hex_digit_value(hex[0]) * 16 + hex_digit_value(hex[1]));
        hex += 2;
    }
    return count;
}

#endif
