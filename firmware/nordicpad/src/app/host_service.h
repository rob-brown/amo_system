#ifndef APP_HOST_SERVICE_H
#define APP_HOST_SERVICE_H

#include "controller/controller_input.h"
#include "host/host_commands.h"
#include "host/host_link.h"
#include "nfc/amiibo_store.h"
#include "platform/host_transport.h"

typedef struct {
    host_link_t link;
    host_commands_t commands;
    controller_input_t input;
    amiibo_store_t amiibo;
    host_transport_t transport;
    host_connection_state_t published_state;
} host_service_t;

void host_service_init(host_service_t *service, const host_transport_t *transport,
                       host_connection_state_t (*connection_state)(void *context), void *context);

void host_service_start(host_service_t *service);

void host_service_publish_connection(host_service_t *service, host_connection_state_t state);

#endif
