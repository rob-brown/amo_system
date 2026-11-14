#include "protocol/command_frame.h"

#include <string.h>

#define HEADER_COMMAND_INDEX 0
#define HEADER_DIRECTION_INDEX 1
#define HEADER_TRANSPORT_INDEX 2
#define HEADER_SUBCOMMAND_INDEX 3
#define HEADER_REQUEST_LENGTH_INDEX 5

static const uint8_t REPLY_HEADER_TAIL[] = {0x10, 0x78, 0x00, 0x00};

command_frame_status_t command_frame_parse_request(const uint8_t *value,
                                                   size_t value_length,
                                                   size_t prefix_size,
                                                   command_request_t *request) {
    if (value_length < prefix_size + COMMAND_HEADER_SIZE) {
        return COMMAND_FRAME_TOO_SHORT;
    }

    const uint8_t *header = &value[prefix_size];
    if (header[HEADER_DIRECTION_INDEX] != COMMAND_DIRECTION_REQUEST) {
        return COMMAND_FRAME_NOT_A_REQUEST;
    }

    size_t payload_length = header[HEADER_REQUEST_LENGTH_INDEX];
    size_t available = value_length - prefix_size - COMMAND_HEADER_SIZE;
    if (payload_length > available) {
        return COMMAND_FRAME_LENGTH_EXCEEDS_DATA;
    }

    request->command = header[HEADER_COMMAND_INDEX];
    request->subcommand = header[HEADER_SUBCOMMAND_INDEX];
    request->transport = header[HEADER_TRANSPORT_INDEX];
    request->payload = &header[COMMAND_HEADER_SIZE];
    request->payload_length = payload_length;
    return COMMAND_FRAME_OK;
}

size_t command_frame_build_reply(const command_request_t *request,
                                 const uint8_t *payload,
                                 size_t payload_length,
                                 uint8_t *output,
                                 size_t output_capacity) {
    size_t total = COMMAND_HEADER_SIZE + payload_length;
    if (output_capacity < total) {
        return 0;
    }

    output[HEADER_COMMAND_INDEX] = request->command;
    output[HEADER_DIRECTION_INDEX] = COMMAND_DIRECTION_REPLY;
    output[HEADER_TRANSPORT_INDEX] = request->transport;
    output[HEADER_SUBCOMMAND_INDEX] = request->subcommand;
    memcpy(&output[HEADER_SUBCOMMAND_INDEX + 1], REPLY_HEADER_TAIL, sizeof(REPLY_HEADER_TAIL));
    if (payload_length > 0) {
        memcpy(&output[COMMAND_HEADER_SIZE], payload, payload_length);
    }
    return total;
}
