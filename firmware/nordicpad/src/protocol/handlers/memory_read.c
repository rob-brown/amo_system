#include "protocol/handlers/memory_read.h"

#include <string.h>

#include "controller/identity.h"

#define REQUEST_SIZE 8
#define REQUEST_LENGTH_INDEX 0
#define REQUEST_ADDRESS_INDEX 4
#define REPLY_HEADER_SIZE 8
#define REPLY_ADDRESS_INDEX 4

static uint32_t read_address(const uint8_t *bytes) {
    return (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) | ((uint32_t)bytes[2] << 16) |
           ((uint32_t)bytes[3] << 24);
}

size_t memory_read_handle(void *context,
                          const command_request_t *request,
                          uint8_t *payload,
                          size_t capacity) {
    const controller_identity_t *identity = context;

    if (request->payload_length < REQUEST_SIZE) {
        return 0;
    }

    size_t length = request->payload[REQUEST_LENGTH_INDEX];
    uint32_t address = read_address(&request->payload[REQUEST_ADDRESS_INDEX]);
    if (REPLY_HEADER_SIZE + length > capacity) {
        return 0;
    }

    memset(payload, 0, REPLY_HEADER_SIZE);
    payload[REQUEST_LENGTH_INDEX] = (uint8_t)length;
    memcpy(&payload[REPLY_ADDRESS_INDEX], &request->payload[REQUEST_ADDRESS_INDEX], sizeof(uint32_t));
    identity_read_memory(identity, address, length, &payload[REPLY_HEADER_SIZE]);
    return REPLY_HEADER_SIZE + length;
}
