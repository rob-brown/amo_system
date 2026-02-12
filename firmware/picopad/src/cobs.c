#include "cobs.h"

size_t cobs_encode(const uint8_t *input, size_t length, uint8_t *output, size_t output_size) {
    if (input == NULL || output == NULL || length == 0 || output_size == 0) {
        return 0;
    }

    size_t max_encoded = cobs_encoded_size_max(length);
    if (output_size < max_encoded) {
        return 0;
    }

    size_t read_idx = 0;
    size_t write_idx = 1;
    size_t code_idx = 0;
    uint8_t code = 1;

    while (read_idx < length) {
        if (input[read_idx] == 0) {
            output[code_idx] = code;
            code_idx = write_idx++;
            code = 1;
        } else {
            output[write_idx++] = input[read_idx];
            code++;
            if (code == 0xFF) {
                output[code_idx] = code;
                code_idx = write_idx++;
                code = 1;
            }
        }
        read_idx++;
    }
    output[code_idx] = code;

    return write_idx;
}

size_t cobs_decode(const uint8_t *input, size_t length, uint8_t *output, size_t output_size) {
    if (input == NULL || output == NULL || length == 0 || output_size == 0) {
        return 0;
    }

    size_t read_idx = 0;
    size_t write_idx = 0;

    while (read_idx < length) {
        uint8_t code = input[read_idx++];

        if (code == 0) {
            return 0;
        }

        for (uint8_t i = 1; i < code; i++) {
            if (read_idx >= length) {
                return 0;
            }
            if (write_idx >= output_size) {
                return 0;
            }
            output[write_idx++] = input[read_idx++];
        }

        if (code < 0xFF && read_idx < length) {
            if (write_idx >= output_size) {
                return 0;
            }
            output[write_idx++] = 0;
        }
    }

    return write_idx;
}

size_t cobs_encoded_size_max(size_t input_length) {
    return input_length + (input_length / 254) + 1;
}
