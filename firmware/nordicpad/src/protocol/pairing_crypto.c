#include "protocol/pairing_crypto.h"

#include <string.h>

#include "protocol/aes128.h"
#include "util/byte_order.h"

static const uint8_t CONTROLLER_KEY[PAIRING_KEY_SIZE] = {
    0x5C, 0xF6, 0xEE, 0x79, 0x2C, 0xDF, 0x05, 0xE1,
    0xBA, 0x2B, 0x63, 0x25, 0xC4, 0x1A, 0x5F, 0x10,
};

void pairing_controller_key(uint8_t controller_key[PAIRING_KEY_SIZE]) {
    memcpy(controller_key, CONTROLLER_KEY, PAIRING_KEY_SIZE);
}

void pairing_derive_link_key(const uint8_t host_key[PAIRING_KEY_SIZE],
                             uint8_t link_key[PAIRING_KEY_SIZE]) {
    byte_order_xor(link_key, host_key, CONTROLLER_KEY, PAIRING_KEY_SIZE);
}

void pairing_answer_challenge(const uint8_t link_key[PAIRING_KEY_SIZE],
                              const uint8_t challenge[PAIRING_KEY_SIZE],
                              uint8_t response[PAIRING_KEY_SIZE]) {
    uint8_t cipher_key[AES128_KEY_SIZE];
    uint8_t cipher_input[AES128_BLOCK_SIZE];

    byte_order_reverse(cipher_key, link_key, AES128_KEY_SIZE);
    byte_order_reverse(cipher_input, challenge, AES128_BLOCK_SIZE);
    aes128_encrypt_block(cipher_key, cipher_input, response);
}
