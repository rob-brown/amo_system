#ifndef PROTOCOL_PAIRING_H
#define PROTOCOL_PAIRING_H

#include <stdbool.h>
#include <stdint.h>

#include "protocol/pairing_crypto.h"
#include "storage/pairing_store.h"

#define PAIRING_ADDRESS_SIZE 6

typedef struct {
    const pairing_store_t *store;
    uint8_t local_address_le[PAIRING_ADDRESS_SIZE];
    uint8_t link_key[PAIRING_KEY_SIZE];
    bool has_link_key;
    uint8_t pending_key[PAIRING_KEY_SIZE];
    bool has_pending_key;
    uint8_t host_address_le[PAIRING_ADDRESS_SIZE];
    bool has_host_address;
    uint8_t pending_host_address_le[PAIRING_ADDRESS_SIZE];
    bool has_pending_host_address;
} pairing_t;

void pairing_init(pairing_t *pairing,
                  const pairing_store_t *store,
                  const uint8_t local_address_le[PAIRING_ADDRESS_SIZE]);

void pairing_exchange_keys(pairing_t *pairing,
                           const uint8_t host_key[PAIRING_KEY_SIZE],
                           uint8_t controller_key[PAIRING_KEY_SIZE]);

bool pairing_answer(const pairing_t *pairing,
                    const uint8_t challenge[PAIRING_KEY_SIZE],
                    uint8_t response[PAIRING_KEY_SIZE]);

void pairing_remember_host_address(pairing_t *pairing, const uint8_t host_address_le[PAIRING_ADDRESS_SIZE]);

bool pairing_commit(pairing_t *pairing);

bool pairing_get_host_address(const pairing_t *pairing, uint8_t host_address_le[PAIRING_ADDRESS_SIZE]);

bool pairing_get_link_key(const pairing_t *pairing, uint8_t link_key[PAIRING_KEY_SIZE]);

#endif
