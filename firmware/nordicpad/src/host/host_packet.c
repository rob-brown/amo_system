#include "host/host_packet.h"

#include <string.h>

#include "host/crc8.h"

#define LENGTH_OFFSET 0
#define COMMAND_OFFSET 2
#define BODY_OFFSET 3

static size_t seal_packet(uint8_t *out, size_t total) {
    out[LENGTH_OFFSET] = (uint8_t)(total & 0xFF);
    out[LENGTH_OFFSET + 1] = (uint8_t)(total >> 8);
    out[total - 1] = crc8(out, total - 1);
    return total;
}

size_t host_packet_build_event(uint8_t event, const uint8_t *payload, size_t payload_length, uint8_t *out, size_t capacity) {
    size_t total = HOST_REQUEST_OVERHEAD + payload_length;
    if (payload_length > HOST_PACKET_MAX_PAYLOAD || capacity < total) {
        return 0;
    }

    out[COMMAND_OFFSET] = event;
    if (payload_length > 0) {
        memcpy(&out[BODY_OFFSET], payload, payload_length);
    }
    return seal_packet(out, total);
}

size_t host_packet_build_response(uint8_t command, uint8_t status, const uint8_t *payload, size_t payload_length, uint8_t *out,
                                  size_t capacity) {
    size_t total = HOST_RESPONSE_OVERHEAD + payload_length;
    if (payload_length > HOST_PACKET_MAX_PAYLOAD || capacity < total) {
        return 0;
    }

    out[COMMAND_OFFSET] = command;
    out[BODY_OFFSET] = status;
    if (payload_length > 0) {
        memcpy(&out[BODY_OFFSET + 1], payload, payload_length);
    }
    return seal_packet(out, total);
}

bool host_packet_parse_request(const uint8_t *data, size_t length, host_request_t *request) {
    if (length < HOST_REQUEST_OVERHEAD) {
        return false;
    }

    size_t declared = (size_t)data[LENGTH_OFFSET] | ((size_t)data[LENGTH_OFFSET + 1] << 8);
    if (declared != length || crc8(data, length - 1) != data[length - 1]) {
        return false;
    }

    request->command = data[COMMAND_OFFSET];
    request->payload_length = length - HOST_REQUEST_OVERHEAD;
    request->payload = request->payload_length > 0 ? &data[BODY_OFFSET] : NULL;
    return true;
}
