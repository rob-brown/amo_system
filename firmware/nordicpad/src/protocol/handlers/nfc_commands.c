#include "protocol/handlers/nfc_commands.h"

#include "nfc/nfc_session.h"

size_t nfc_configure_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity) {
    (void)payload;
    (void)capacity;
    nfc_session_configure(context, request->payload, request->payload_length);
    return 0;
}

size_t nfc_end_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity) {
    (void)request;
    (void)payload;
    (void)capacity;
    nfc_session_end(context);
    return 0;
}

size_t nfc_poll_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity) {
    (void)request;
    return nfc_session_poll(context, payload, capacity);
}

size_t nfc_start_read_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity) {
    (void)payload;
    (void)capacity;
    nfc_session_start_read(context, request->payload, request->payload_length);
    return 0;
}

size_t nfc_read_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity) {
    return nfc_session_read(context, request->payload, request->payload_length, payload, capacity);
}

size_t nfc_write_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity) {
    (void)context;
    (void)request;
    (void)payload;
    (void)capacity;
    return 0;
}

size_t nfc_commit_write_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity) {
    (void)request;
    (void)payload;
    (void)capacity;
    nfc_session_commit_write(context);
    return 0;
}

size_t nfc_read_registry_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity) {
    (void)payload;
    (void)capacity;
    nfc_session_read_registry(context, request->payload, request->payload_length);
    return 0;
}
