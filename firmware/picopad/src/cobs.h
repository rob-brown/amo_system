#ifndef COBS_H
#define COBS_H

#include <stddef.h>
#include <stdint.h>

#define COBS_DELIMITER 0x00
#define COBS_MAX_BLOCK_SIZE 254

size_t cobs_encode(const uint8_t *input, size_t length, uint8_t *output, size_t output_size);
size_t cobs_decode(const uint8_t *input, size_t length, uint8_t *output, size_t output_size);
size_t cobs_encoded_size_max(size_t input_length);

#endif
