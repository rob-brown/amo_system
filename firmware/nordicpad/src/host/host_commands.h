#ifndef HOST_HOST_COMMANDS_H
#define HOST_HOST_COMMANDS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "controller/controller_input.h"
#include "controller/profile.h"
#include "host/host_ids.h"
#include "host/host_packet.h"
#include "nfc/amiibo_store.h"

typedef struct {
    uint8_t status;
    const uint8_t *payload;
    size_t length;
} host_response_t;

typedef struct {
    void (*set_colors)(void *context, const controller_colors_t *colors);
    void *context;
} host_appearance_t;

typedef struct {
    void (*reboot)(void *context, host_reboot_target_t target);
    void *context;
} host_system_t;

typedef struct {
    void (*start_advertising)(void *context);
    void (*stop_advertising)(void *context);
    uint8_t (*reconnect)(void *context);
    bool (*forget_bonding)(void *context);
    void *context;
} host_radio_t;

typedef struct {
    controller_input_t *input;
    amiibo_store_t *amiibo;
    host_appearance_t appearance;
    host_system_t system;
    host_radio_t radio;
    uint8_t controller;
    host_connection_state_t (*connection_state)(void *context);
    void *context;
    uint8_t reply[HOST_PACKET_MAX_PAYLOAD];
    size_t reply_length;
} host_commands_t;

void host_commands_init(host_commands_t *commands, controller_input_t *input, amiibo_store_t *amiibo,
                        host_connection_state_t (*connection_state)(void *context), void *context);

void host_commands_set_appearance(host_commands_t *commands, const host_appearance_t *appearance);

void host_commands_set_system(host_commands_t *commands, const host_system_t *system);

void host_commands_set_radio(host_commands_t *commands, const host_radio_t *radio);

void host_commands_set_controller_type(host_commands_t *commands, controller_type_t type);

host_response_t host_commands_handle(host_commands_t *commands, const host_request_t *request);

#endif
