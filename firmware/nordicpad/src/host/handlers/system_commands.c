#include "host/handlers/host_handlers.h"

uint8_t host_handle_reset(host_commands_t *commands, const host_request_t *request) {
    host_reboot_target_t target = HOST_REBOOT_APPLICATION;

    if (request->payload_length > 0) {
        target = (host_reboot_target_t)request->payload[0];
    }
    if (target != HOST_REBOOT_APPLICATION && target != HOST_REBOOT_BOOTLOADER) {
        return HOST_STATUS_INVALID_PARAMS;
    }
    if (commands->system.reboot == NULL) {
        return HOST_STATUS_ERROR;
    }
    commands->system.reboot(commands->system.context, target);
    return HOST_STATUS_OK;
}
