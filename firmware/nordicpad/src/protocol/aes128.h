#ifndef PROTOCOL_AES128_H
#define PROTOCOL_AES128_H

#include <stdint.h>

#define AES128_KEY_SIZE 16
#define AES128_BLOCK_SIZE 16

void aes128_encrypt_block(const uint8_t key[AES128_KEY_SIZE],
                          const uint8_t input[AES128_BLOCK_SIZE],
                          uint8_t output[AES128_BLOCK_SIZE]);

#endif
