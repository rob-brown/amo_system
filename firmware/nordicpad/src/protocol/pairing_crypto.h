#ifndef PROTOCOL_PAIRING_CRYPTO_H
#define PROTOCOL_PAIRING_CRYPTO_H

#include <stdint.h>

#define PAIRING_KEY_SIZE 16

void pairing_controller_key(uint8_t controller_key[PAIRING_KEY_SIZE]);

void pairing_derive_link_key(const uint8_t host_key[PAIRING_KEY_SIZE],
                             uint8_t link_key[PAIRING_KEY_SIZE]);

void pairing_answer_challenge(const uint8_t link_key[PAIRING_KEY_SIZE],
                              const uint8_t challenge[PAIRING_KEY_SIZE],
                              uint8_t response[PAIRING_KEY_SIZE]);

#endif
