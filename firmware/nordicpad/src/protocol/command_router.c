#include "protocol/command_router.h"

static const command_route_t *find_route(const command_router_t *router,
                                         const command_request_t *request) {
    for (size_t index = 0; index < router->route_count; index++) {
        const command_route_t *route = &router->routes[index];
        if (route->command == request->command && route->subcommand == request->subcommand) {
            return route;
        }
    }
    return NULL;
}

command_router_status_t command_router_dispatch(const command_router_t *router,
                                                const command_request_t *request,
                                                uint8_t *payload,
                                                size_t capacity,
                                                size_t *payload_length) {
    const command_route_t *route = find_route(router, request);
    if (route == NULL) {
        return COMMAND_ROUTER_UNKNOWN;
    }

    *payload_length = route->handler(route->context, request, payload, capacity);
    return COMMAND_ROUTER_HANDLED;
}
