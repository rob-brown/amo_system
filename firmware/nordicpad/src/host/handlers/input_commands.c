#include <string.h>

#include "host/handlers/host_handlers.h"

#define SET_BUTTONS_PAYLOAD_SIZE 6
#define SET_STICK_PAYLOAD_SIZE 5
#define SET_PRESET_PAYLOAD_SIZE 2
#define PRESS_PAYLOAD_SIZE 3

static const uint8_t ALL_BITS[CONTROLLER_INPUT_BITFIELD_SIZE] = {0xFF, 0xFF, 0xFF};

static uint16_t read_u16(const uint8_t *bytes) {
    return (uint16_t)(bytes[0] | (bytes[1] << 8));
}

static void write_u16(uint8_t *bytes, uint16_t value) {
    bytes[0] = (uint8_t)(value & 0xFF);
    bytes[1] = (uint8_t)(value >> 8);
}

uint8_t host_handle_set_buttons(host_commands_t *commands, const host_request_t *request) {
    if (request->payload_length < SET_BUTTONS_PAYLOAD_SIZE) {
        return HOST_STATUS_INVALID_PARAMS;
    }
    controller_input_set_buttons(commands->input, request->payload, &request->payload[CONTROLLER_INPUT_BITFIELD_SIZE]);
    return HOST_STATUS_OK;
}

uint8_t host_handle_set_all_buttons(host_commands_t *commands, const host_request_t *request) {
    if (request->payload_length < CONTROLLER_INPUT_BITFIELD_SIZE) {
        return HOST_STATUS_INVALID_PARAMS;
    }
    controller_input_set_buttons(commands->input, request->payload, ALL_BITS);
    return HOST_STATUS_OK;
}

uint8_t host_handle_clear_buttons(host_commands_t *commands, const host_request_t *request) {
    (void)request;
    controller_input_clear_buttons(commands->input);
    return HOST_STATUS_OK;
}

uint8_t host_handle_set_stick(host_commands_t *commands, const host_request_t *request) {
    if (request->payload_length < SET_STICK_PAYLOAD_SIZE) {
        return HOST_STATUS_INVALID_PARAMS;
    }
    const uint8_t *payload = request->payload;
    bool accepted = controller_input_set_stick(commands->input, payload[0], read_u16(&payload[1]), read_u16(&payload[3]));
    return accepted ? HOST_STATUS_OK : HOST_STATUS_INVALID_PARAMS;
}

uint8_t host_handle_set_stick_preset(host_commands_t *commands, const host_request_t *request) {
    if (request->payload_length < SET_PRESET_PAYLOAD_SIZE) {
        return HOST_STATUS_INVALID_PARAMS;
    }
    bool accepted = controller_input_set_stick_preset(commands->input, request->payload[0], request->payload[1]);
    return accepted ? HOST_STATUS_OK : HOST_STATUS_INVALID_PARAMS;
}

uint8_t host_handle_get_input_state(host_commands_t *commands, const host_request_t *request) {
    (void)request;
    uint8_t buttons[CONTROLLER_INPUT_BITFIELD_SIZE];
    uint16_t sticks[CONTROLLER_INPUT_STICK_COUNT][2];
    controller_input_get_state(commands->input, buttons, sticks);

    uint8_t *reply = commands->reply;
    memcpy(reply, buttons, sizeof(buttons));
    write_u16(&reply[3], sticks[HOST_STICK_LEFT][0]);
    write_u16(&reply[5], sticks[HOST_STICK_LEFT][1]);
    write_u16(&reply[7], sticks[HOST_STICK_RIGHT][0]);
    write_u16(&reply[9], sticks[HOST_STICK_RIGHT][1]);
    commands->reply_length = 11;
    return HOST_STATUS_OK;
}

uint8_t host_handle_press_button(host_commands_t *commands, const host_request_t *request) {
    if (request->payload_length < PRESS_PAYLOAD_SIZE) {
        return HOST_STATUS_INVALID_PARAMS;
    }
    bool accepted = controller_input_press(commands->input, request->payload[0], read_u16(&request->payload[1]));
    return accepted ? HOST_STATUS_OK : HOST_STATUS_INVALID_PARAMS;
}
