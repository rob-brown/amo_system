#include "host/host_commands.h"

#include <string.h>

#include "host/handlers/host_handlers.h"

#define STATUS_REPLY_SIZE 10
#define NO_PLAYER 0xFF
#define VERSION_MAJOR 0
#define VERSION_MINOR 2
#define VERSION_PATCH 0
#define VERSION_STRING "nordicpad 0.2.0"

typedef struct {
    uint8_t command;
    host_handler_t handler;
} command_entry_t;

static uint8_t handle_get_status(host_commands_t *commands, const host_request_t *request) {
    (void)request;
    memset(commands->reply, 0, STATUS_REPLY_SIZE);
    commands->reply[0] = commands->connection_state(commands->context);
    commands->reply[1] = commands->controller;
    commands->reply[2] = NO_PLAYER;
    commands->reply[3] = amiibo_store_is_loaded(commands->amiibo) ? 1 : 0;
    commands->reply_length = STATUS_REPLY_SIZE;
    return HOST_STATUS_OK;
}

static uint8_t handle_ping(host_commands_t *commands, const host_request_t *request) {
    if (request->payload_length > 0) {
        memcpy(commands->reply, request->payload, request->payload_length);
    }
    commands->reply_length = request->payload_length;
    return HOST_STATUS_OK;
}

static uint8_t handle_get_version(host_commands_t *commands, const host_request_t *request) {
    (void)request;
    commands->reply[0] = VERSION_MAJOR;
    commands->reply[1] = VERSION_MINOR;
    commands->reply[2] = VERSION_PATCH;
    memcpy(&commands->reply[3], VERSION_STRING, sizeof(VERSION_STRING));
    commands->reply_length = 3 + sizeof(VERSION_STRING);
    return HOST_STATUS_OK;
}

static const command_entry_t COMMAND_TABLE[] = {
    {HOST_CMD_GET_STATUS, handle_get_status},
    {HOST_CMD_START_ADVERTISING, host_handle_start_advertising},
    {HOST_CMD_STOP_ADVERTISING, host_handle_stop_advertising},
    {HOST_CMD_RECONNECT, host_handle_reconnect},
    {HOST_CMD_FORGET_BONDING, host_handle_forget_bonding},
    {HOST_CMD_SET_BUTTONS, host_handle_set_buttons},
    {HOST_CMD_SET_ALL_BUTTONS, host_handle_set_all_buttons},
    {HOST_CMD_CLEAR_BUTTONS, host_handle_clear_buttons},
    {HOST_CMD_SET_STICK, host_handle_set_stick},
    {HOST_CMD_SET_STICK_PRESET, host_handle_set_stick_preset},
    {HOST_CMD_GET_INPUT_STATE, host_handle_get_input_state},
    {HOST_CMD_PRESS_BUTTON, host_handle_press_button},
    {HOST_CMD_AMIIBO_GET_STATUS, host_handle_amiibo_get_status},
    {HOST_CMD_AMIIBO_LOAD, host_handle_amiibo_load},
    {HOST_CMD_AMIIBO_LOAD_START, host_handle_amiibo_load_start},
    {HOST_CMD_AMIIBO_LOAD_CHUNK, host_handle_amiibo_load_chunk},
    {HOST_CMD_AMIIBO_LOAD_FINISH, host_handle_amiibo_load_finish},
    {HOST_CMD_AMIIBO_READ, host_handle_amiibo_read},
    {HOST_CMD_AMIIBO_READ_CHUNK, host_handle_amiibo_read_chunk},
    {HOST_CMD_AMIIBO_CLEAR, host_handle_amiibo_clear},
    {HOST_CMD_AMIIBO_SET_READONLY, host_handle_amiibo_set_readonly},
    {HOST_CMD_SET_COLORS, host_handle_set_colors},
    {HOST_CMD_PING, handle_ping},
    {HOST_CMD_GET_VERSION, handle_get_version},
    {HOST_CMD_RESET, host_handle_reset},
};

void host_commands_init(host_commands_t *commands, controller_input_t *input, amiibo_store_t *amiibo,
                        host_connection_state_t (*connection_state)(void *context), void *context) {
    memset(commands, 0, sizeof(*commands));
    commands->input = input;
    commands->amiibo = amiibo;
    commands->controller = HOST_CONTROLLER_JOYCON_R;
    commands->connection_state = connection_state;
    commands->context = context;
}

void host_commands_set_appearance(host_commands_t *commands, const host_appearance_t *appearance) {
    commands->appearance = *appearance;
}

void host_commands_set_system(host_commands_t *commands, const host_system_t *system) {
    commands->system = *system;
}

void host_commands_set_radio(host_commands_t *commands, const host_radio_t *radio) {
    commands->radio = *radio;
}

void host_commands_set_controller_type(host_commands_t *commands, controller_type_t type) {
    switch (type) {
    case CONTROLLER_TYPE_JOYCON_L:
        commands->controller = HOST_CONTROLLER_JOYCON_L;
        break;
    case CONTROLLER_TYPE_JOYCON_R:
        commands->controller = HOST_CONTROLLER_JOYCON_R;
        break;
    case CONTROLLER_TYPE_PRO_CONTROLLER:
        commands->controller = HOST_CONTROLLER_PRO;
        break;
    }
}

host_response_t host_commands_handle(host_commands_t *commands, const host_request_t *request) {
    commands->reply_length = 0;

    for (size_t index = 0; index < sizeof(COMMAND_TABLE) / sizeof(COMMAND_TABLE[0]); index++) {
        if (COMMAND_TABLE[index].command == request->command) {
            uint8_t status = COMMAND_TABLE[index].handler(commands, request);
            size_t length = status == HOST_STATUS_OK ? commands->reply_length : 0;
            return (host_response_t){status, commands->reply, length};
        }
    }
    return (host_response_t){HOST_STATUS_UNKNOWN_CMD, commands->reply, 0};
}
