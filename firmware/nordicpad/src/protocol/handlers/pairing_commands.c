#include "protocol/handlers/pairing_commands.h"

#include <string.h>

#include "protocol/pairing.h"

#define STATUS_OK 0x01
#define KEY_REQUEST_SIZE (1 + PAIRING_KEY_SIZE)
#define KEY_REPLY_SIZE (1 + PAIRING_KEY_SIZE)
#define KEY_INDEX 1
#define HOST_ADDRESSES_REPLY_PREFIX_SIZE 3
#define HOST_ADDRESS_REQUEST_INDEX 2
#define HOST_ADDRESS_REQUEST_SIZE (HOST_ADDRESS_REQUEST_INDEX + PAIRING_ADDRESS_SIZE)

static const uint8_t HOST_ADDRESSES_REPLY_PREFIX[HOST_ADDRESSES_REPLY_PREFIX_SIZE] = {STATUS_OK, 0x04, 0x01};

static size_t reply_with_key(uint8_t *payload, size_t capacity, const uint8_t key[PAIRING_KEY_SIZE]) {
    if (capacity < KEY_REPLY_SIZE) {
        return 0;
    }

    payload[0] = STATUS_OK;
    memcpy(&payload[KEY_INDEX], key, PAIRING_KEY_SIZE);
    return KEY_REPLY_SIZE;
}

size_t pairing_host_addresses_handle(void *context,
                                     const command_request_t *request,
                                     uint8_t *payload,
                                     size_t capacity) {
    pairing_t *pairing = context;

    if (capacity < HOST_ADDRESSES_REPLY_PREFIX_SIZE + PAIRING_ADDRESS_SIZE) {
        return 0;
    }
    if (request->payload_length >= HOST_ADDRESS_REQUEST_SIZE) {
        pairing_remember_host_address(pairing, &request->payload[HOST_ADDRESS_REQUEST_INDEX]);
    }

    memcpy(payload, HOST_ADDRESSES_REPLY_PREFIX, HOST_ADDRESSES_REPLY_PREFIX_SIZE);
    memcpy(&payload[HOST_ADDRESSES_REPLY_PREFIX_SIZE], pairing->local_address_le, PAIRING_ADDRESS_SIZE);
    return HOST_ADDRESSES_REPLY_PREFIX_SIZE + PAIRING_ADDRESS_SIZE;
}

size_t pairing_key_exchange_handle(void *context,
                                   const command_request_t *request,
                                   uint8_t *payload,
                                   size_t capacity) {
    pairing_t *pairing = context;
    uint8_t controller_key[PAIRING_KEY_SIZE];

    if (request->payload_length < KEY_REQUEST_SIZE) {
        return 0;
    }

    pairing_exchange_keys(pairing, &request->payload[KEY_INDEX], controller_key);
    return reply_with_key(payload, capacity, controller_key);
}

size_t pairing_challenge_handle(void *context,
                                const command_request_t *request,
                                uint8_t *payload,
                                size_t capacity) {
    const pairing_t *pairing = context;
    uint8_t response[PAIRING_KEY_SIZE];

    if (request->payload_length < KEY_REQUEST_SIZE) {
        return 0;
    }
    if (!pairing_answer(pairing, &request->payload[KEY_INDEX], response)) {
        return 0;
    }

    return reply_with_key(payload, capacity, response);
}

size_t pairing_finalise_handle(void *context,
                               const command_request_t *request,
                               uint8_t *payload,
                               size_t capacity) {
    pairing_t *pairing = context;
    (void)request;

    if (capacity < 1 || !pairing_commit(pairing)) {
        return 0;
    }

    payload[0] = STATUS_OK;
    return 1;
}
