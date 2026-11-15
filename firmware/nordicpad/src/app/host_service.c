#include "app/host_service.h"

#include <string.h>

#include "platform/log.h"

#define CONNECTION_EVENT_SIZE 7

static void on_request(void *context, const host_request_t *request) {
    host_service_t *service = context;
    host_response_t response = host_commands_handle(&service->commands, request);
    LOG("host command %02x answered with status %02x", request->command, response.status);
    host_link_send_response(&service->link, request->command, response.status, response.payload, response.length);
}

static void write_to_transport(void *context, const uint8_t *data, size_t length) {
    host_service_t *service = context;
    if (service->transport.write != NULL) {
        service->transport.write(service->transport.context, data, length);
    }
}

static void on_receive(void *context, const uint8_t *data, size_t length) {
    host_service_t *service = context;
    host_link_receive(&service->link, data, length);
}

void host_service_init(host_service_t *service, const host_transport_t *transport,
                       host_connection_state_t (*connection_state)(void *context), void *context) {
    memset(service, 0, sizeof(*service));
    service->transport = *transport;
    service->published_state = HOST_CONNECTION_DISCONNECTED;

    controller_input_init(&service->input);
    amiibo_store_init(&service->amiibo);
    host_commands_init(&service->commands, &service->input, &service->amiibo, connection_state, context);

    const host_link_config_t link_config = {on_request, write_to_transport, service};
    host_link_init(&service->link, &link_config);
}

void host_service_start(host_service_t *service) {
    if (service->transport.start != NULL) {
        service->transport.start(service->transport.context, on_receive, service);
    }
}

void host_service_publish_connection(host_service_t *service, host_connection_state_t state) {
    if (state == service->published_state) {
        return;
    }
    service->published_state = state;

    uint8_t payload[CONNECTION_EVENT_SIZE] = {(uint8_t)state};
    host_link_send_event(&service->link, HOST_EVT_CONNECTION_CHANGED, payload, sizeof(payload));
}

void host_service_publish_bonding_cleared(host_service_t *service) {
    host_link_send_event(&service->link, HOST_EVT_BONDING_CLEARED, NULL, 0);
}

void host_service_publish_amiibo_scanned(host_service_t *service, bool write_request) {
    uint8_t payload[] = {write_request ? 1 : 0};
    host_link_send_event(&service->link, HOST_EVT_AMIIBO_SCANNED, payload, sizeof(payload));
}

void host_service_publish_amiibo_write_complete(host_service_t *service, bool succeeded) {
    uint8_t payload[] = {succeeded ? 0 : 1};
    host_link_send_event(&service->link, HOST_EVT_AMIIBO_WRITE_COMPLETE, payload, sizeof(payload));
}

void host_service_publish_reconnect_result(host_service_t *service, bool succeeded) {
    host_link_send_event(&service->link, succeeded ? HOST_EVT_RECONNECT_SUCCESS : HOST_EVT_RECONNECT_FAILED, NULL, 0);
}
