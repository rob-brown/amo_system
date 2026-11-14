#include "protocol/pairing.h"

#include <string.h>

static bool is_zero_address(const uint8_t address[PAIRING_ADDRESS_SIZE]) {
    static const uint8_t ZERO[PAIRING_ADDRESS_SIZE] = {0};
    return memcmp(address, ZERO, PAIRING_ADDRESS_SIZE) == 0;
}

void pairing_init(pairing_t *pairing,
                  const pairing_store_t *store,
                  const uint8_t local_address_le[PAIRING_ADDRESS_SIZE]) {
    memset(pairing, 0, sizeof(*pairing));
    pairing->store = store;
    memcpy(pairing->local_address_le, local_address_le, PAIRING_ADDRESS_SIZE);

    pairing_record_t record;
    if (store->load(store->context, &record)) {
        memcpy(pairing->link_key, record.link_key, PAIRING_KEY_SIZE);
        pairing->has_link_key = true;
        if (!is_zero_address(record.host_address)) {
            memcpy(pairing->host_address_le, record.host_address, PAIRING_ADDRESS_SIZE);
            pairing->has_host_address = true;
        }
    }
}

void pairing_exchange_keys(pairing_t *pairing,
                           const uint8_t host_key[PAIRING_KEY_SIZE],
                           uint8_t controller_key[PAIRING_KEY_SIZE]) {
    pairing_controller_key(controller_key);
    pairing_derive_link_key(host_key, pairing->pending_key);
    pairing->has_pending_key = true;
}

bool pairing_answer(const pairing_t *pairing,
                    const uint8_t challenge[PAIRING_KEY_SIZE],
                    uint8_t response[PAIRING_KEY_SIZE]) {
    if (!pairing->has_pending_key) {
        return false;
    }

    pairing_answer_challenge(pairing->pending_key, challenge, response);
    return true;
}

void pairing_remember_host_address(pairing_t *pairing, const uint8_t host_address_le[PAIRING_ADDRESS_SIZE]) {
    memcpy(pairing->pending_host_address_le, host_address_le, PAIRING_ADDRESS_SIZE);
    pairing->has_pending_host_address = true;
}

bool pairing_commit(pairing_t *pairing) {
    if (!pairing->has_pending_key) {
        return false;
    }

    pairing_record_t record;
    memcpy(record.link_key, pairing->pending_key, PAIRING_KEY_SIZE);
    memset(record.host_address, 0, sizeof(record.host_address));
    if (pairing->has_pending_host_address) {
        memcpy(record.host_address, pairing->pending_host_address_le, PAIRING_ADDRESS_SIZE);
    }
    if (!pairing->store->save(pairing->store->context, &record)) {
        return false;
    }

    memcpy(pairing->link_key, pairing->pending_key, PAIRING_KEY_SIZE);
    pairing->has_link_key = true;
    pairing->has_pending_key = false;
    if (pairing->has_pending_host_address) {
        memcpy(pairing->host_address_le, pairing->pending_host_address_le, PAIRING_ADDRESS_SIZE);
        pairing->has_host_address = true;
        pairing->has_pending_host_address = false;
    }
    return true;
}

bool pairing_get_link_key(const pairing_t *pairing, uint8_t link_key[PAIRING_KEY_SIZE]) {
    if (!pairing->has_link_key) {
        return false;
    }

    memcpy(link_key, pairing->link_key, PAIRING_KEY_SIZE);
    return true;
}

bool pairing_get_host_address(const pairing_t *pairing, uint8_t host_address_le[PAIRING_ADDRESS_SIZE]) {
    if (!pairing->has_host_address) {
        return false;
    }

    memcpy(host_address_le, pairing->host_address_le, PAIRING_ADDRESS_SIZE);
    return true;
}
