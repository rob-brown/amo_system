#ifndef PROTOCOL_COMMAND_ROUTER_H
#define PROTOCOL_COMMAND_ROUTER_H

#include <stddef.h>
#include <stdint.h>

#include "protocol/command_frame.h"

typedef size_t (*command_handler_fn)(void *context,
                                     const command_request_t *request,
                                     uint8_t *payload,
                                     size_t capacity);

typedef struct {
    uint8_t command;
    uint8_t subcommand;
    command_handler_fn handler;
    void *context;
} command_route_t;

typedef struct {
    const command_route_t *routes;
    size_t route_count;
} command_router_t;

typedef enum {
    COMMAND_ROUTER_HANDLED,
    COMMAND_ROUTER_UNKNOWN,
} command_router_status_t;

command_router_status_t command_router_dispatch(const command_router_t *router,
                                                const command_request_t *request,
                                                uint8_t *payload,
                                                size_t capacity,
                                                size_t *payload_length);

#endif
