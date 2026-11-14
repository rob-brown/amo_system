#include "host/handlers/host_handlers.h"

uint8_t host_handle_start_advertising(host_commands_t *commands, const host_request_t *request) {
    (void)request;

    if (commands->radio.start_advertising == NULL) {
        return HOST_STATUS_ERROR;
    }
    commands->radio.start_advertising(commands->radio.context);
    return HOST_STATUS_OK;
}

uint8_t host_handle_stop_advertising(host_commands_t *commands, const host_request_t *request) {
    (void)request;

    if (commands->radio.stop_advertising == NULL) {
        return HOST_STATUS_ERROR;
    }
    commands->radio.stop_advertising(commands->radio.context);
    return HOST_STATUS_OK;
}

uint8_t host_handle_reconnect(host_commands_t *commands, const host_request_t *request) {
    (void)request;

    if (commands->radio.reconnect == NULL) {
        return HOST_STATUS_ERROR;
    }
    return commands->radio.reconnect(commands->radio.context);
}

uint8_t host_handle_forget_bonding(host_commands_t *commands, const host_request_t *request) {
    (void)request;

    if (commands->radio.forget_bonding == NULL || !commands->radio.forget_bonding(commands->radio.context)) {
        return HOST_STATUS_ERROR;
    }
    return HOST_STATUS_OK;
}
