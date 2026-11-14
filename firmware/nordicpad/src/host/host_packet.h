#ifndef HOST_HOST_PACKET_H
#define HOST_HOST_PACKET_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define HOST_PACKET_MAX_PAYLOAD 2100
#define HOST_REQUEST_OVERHEAD 4
#define HOST_RESPONSE_OVERHEAD 5
#define HOST_PACKET_MAX_SIZE (HOST_PACKET_MAX_PAYLOAD + HOST_RESPONSE_OVERHEAD)

typedef struct {
    uint8_t command;
    const uint8_t *payload;
    size_t payload_length;
} host_request_t;

size_t host_packet_build_event(uint8_t event, const uint8_t *payload, size_t payload_length, uint8_t *out, size_t capacity);

size_t host_packet_build_response(uint8_t command, uint8_t status, const uint8_t *payload, size_t payload_length, uint8_t *out,
                                  size_t capacity);

bool host_packet_parse_request(const uint8_t *data, size_t length, host_request_t *request);

#endif
