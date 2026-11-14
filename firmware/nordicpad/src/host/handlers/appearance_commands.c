#include <string.h>

#include "host/handlers/host_handlers.h"

uint8_t host_handle_set_colors(host_commands_t *commands, const host_request_t *request) {
    controller_colors_t colors;

    if (request->payload_length < sizeof(colors)) {
        return HOST_STATUS_INVALID_PARAMS;
    }
    if (commands->appearance.set_colors == NULL) {
        return HOST_STATUS_ERROR;
    }
    memcpy(&colors, request->payload, sizeof(colors));
    commands->appearance.set_colors(commands->appearance.context, &colors);
    return HOST_STATUS_OK;
}
