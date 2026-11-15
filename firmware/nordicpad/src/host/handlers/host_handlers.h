#ifndef HOST_HANDLERS_HOST_HANDLERS_H
#define HOST_HANDLERS_HOST_HANDLERS_H

#include <stdint.h>

#include "host/host_commands.h"

typedef uint8_t (*host_handler_t)(host_commands_t *commands, const host_request_t *request);

uint8_t host_handle_set_buttons(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_set_all_buttons(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_clear_buttons(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_set_stick(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_set_stick_preset(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_get_input_state(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_press_button(host_commands_t *commands, const host_request_t *request);

uint8_t host_handle_start_advertising(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_stop_advertising(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_reconnect(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_forget_bonding(host_commands_t *commands, const host_request_t *request);

uint8_t host_handle_reset(host_commands_t *commands, const host_request_t *request);

uint8_t host_handle_set_colors(host_commands_t *commands, const host_request_t *request);

uint8_t host_handle_amiibo_get_status(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_amiibo_load(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_amiibo_load_start(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_amiibo_load_chunk(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_amiibo_load_finish(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_amiibo_read(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_amiibo_read_chunk(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_amiibo_clear(host_commands_t *commands, const host_request_t *request);
uint8_t host_handle_amiibo_set_readonly(host_commands_t *commands, const host_request_t *request);

#endif
