#ifndef PROTOCOL_COMMAND_FRAME_H
#define PROTOCOL_COMMAND_FRAME_H

#include <stddef.h>
#include <stdint.h>

#define COMMAND_HEADER_SIZE 8
#define COMMAND_BASIC_PREFIX_SIZE 17
#define COMMAND_DIRECTION_REQUEST 0x91
#define COMMAND_DIRECTION_REPLY 0x01
#define COMMAND_TRANSPORT_BLE 0x01

typedef enum {
    COMMAND_FRAME_OK,
    COMMAND_FRAME_TOO_SHORT,
    COMMAND_FRAME_NOT_A_REQUEST,
    COMMAND_FRAME_LENGTH_EXCEEDS_DATA,
} command_frame_status_t;

typedef struct {
    uint8_t command;
    uint8_t subcommand;
    uint8_t transport;
    const uint8_t *payload;
    size_t payload_length;
} command_request_t;

command_frame_status_t command_frame_parse_request(const uint8_t *value,
                                                   size_t value_length,
                                                   size_t prefix_size,
                                                   command_request_t *request);

size_t command_frame_build_reply(const command_request_t *request,
                                 const uint8_t *payload,
                                 size_t payload_length,
                                 uint8_t *output,
                                 size_t output_capacity);

#endif
