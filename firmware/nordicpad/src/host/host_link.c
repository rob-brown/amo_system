#include "host/host_link.h"

#include <string.h>

#include "host/cobs.h"

static void reset_frame(host_link_t *link) {
    link->frame_length = 0;
    link->frame_overflowed = false;
}

static void deliver_frame(host_link_t *link) {
    if (link->frame_overflowed || link->frame_length == 0) {
        return;
    }

    size_t decoded = cobs_decode(link->frame, link->frame_length, link->packet, sizeof(link->packet));
    host_request_t request;
    if (decoded == 0 || !host_packet_parse_request(link->packet, decoded, &request)) {
        return;
    }
    link->config.on_request(link->config.context, &request);
}

static bool send_packet(host_link_t *link, size_t packet_length) {
    if (packet_length == 0) {
        return false;
    }

    size_t encoded = cobs_encode(link->outgoing, packet_length, link->encoded, sizeof(link->encoded) - 1);
    if (encoded == 0) {
        return false;
    }
    link->encoded[encoded] = COBS_DELIMITER;
    link->config.write(link->config.context, link->encoded, encoded + 1);
    return true;
}

void host_link_init(host_link_t *link, const host_link_config_t *config) {
    memset(link, 0, sizeof(*link));
    link->config = *config;
}

void host_link_receive(host_link_t *link, const uint8_t *data, size_t length) {
    for (size_t index = 0; index < length; index++) {
        if (data[index] == COBS_DELIMITER) {
            deliver_frame(link);
            reset_frame(link);
        } else if (link->frame_length < sizeof(link->frame)) {
            link->frame[link->frame_length++] = data[index];
        } else {
            link->frame_overflowed = true;
        }
    }
}

bool host_link_send_response(host_link_t *link, uint8_t command, uint8_t status, const uint8_t *payload, size_t payload_length) {
    size_t length = host_packet_build_response(command, status, payload, payload_length, link->outgoing, sizeof(link->outgoing));
    return send_packet(link, length);
}

bool host_link_send_event(host_link_t *link, uint8_t event, const uint8_t *payload, size_t payload_length) {
    size_t length = host_packet_build_event(event, payload, payload_length, link->outgoing, sizeof(link->outgoing));
    return send_packet(link, length);
}
