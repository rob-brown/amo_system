#ifndef HOST_HOST_LINK_H
#define HOST_HOST_LINK_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "host/host_packet.h"

#define HOST_LINK_FRAME_SIZE (HOST_PACKET_MAX_SIZE + (HOST_PACKET_MAX_SIZE / 254) + 2)

typedef struct {
    void (*on_request)(void *context, const host_request_t *request);
    void (*write)(void *context, const uint8_t *data, size_t length);
    void *context;
} host_link_config_t;

typedef struct {
    host_link_config_t config;
    uint8_t frame[HOST_LINK_FRAME_SIZE];
    size_t frame_length;
    bool frame_overflowed;
    uint8_t packet[HOST_PACKET_MAX_SIZE];
    uint8_t outgoing[HOST_PACKET_MAX_SIZE];
    uint8_t encoded[HOST_LINK_FRAME_SIZE];
} host_link_t;

void host_link_init(host_link_t *link, const host_link_config_t *config);

void host_link_receive(host_link_t *link, const uint8_t *data, size_t length);

bool host_link_send_response(host_link_t *link, uint8_t command, uint8_t status, const uint8_t *payload, size_t payload_length);

bool host_link_send_event(host_link_t *link, uint8_t event, const uint8_t *payload, size_t payload_length);

#endif
