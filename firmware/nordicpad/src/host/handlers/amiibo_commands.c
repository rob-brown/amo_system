#include "host/handlers/host_handlers.h"

#define LOAD_HEADER_SIZE 2
#define CHUNK_HEADER_SIZE 1
#define STATUS_REPLY_SIZE 10

static uint16_t read_u16(const uint8_t *bytes) {
    return (uint16_t)(bytes[0] | (bytes[1] << 8));
}

static void reply_uid(host_commands_t *commands) {
    amiibo_store_uid(commands->amiibo, commands->reply);
    commands->reply_length = AMIIBO_UID_SIZE;
}

uint8_t host_handle_amiibo_get_status(host_commands_t *commands, const host_request_t *request) {
    (void)request;
    bool loaded = amiibo_store_is_loaded(commands->amiibo);
    size_t size = loaded ? commands->amiibo->size : 0;

    commands->reply[0] = loaded ? HOST_AMIIBO_LOADED : HOST_AMIIBO_NONE;
    amiibo_store_uid(commands->amiibo, &commands->reply[1]);
    commands->reply[1 + AMIIBO_UID_SIZE] = (uint8_t)(size & 0xFF);
    commands->reply[2 + AMIIBO_UID_SIZE] = (uint8_t)(size >> 8);
    commands->reply_length = STATUS_REPLY_SIZE;
    return HOST_STATUS_OK;
}

uint8_t host_handle_amiibo_load(host_commands_t *commands, const host_request_t *request) {
    if (request->payload_length < LOAD_HEADER_SIZE) {
        return HOST_STATUS_INVALID_PARAMS;
    }
    size_t size = read_u16(request->payload);
    if (request->payload_length < LOAD_HEADER_SIZE + size) {
        return HOST_STATUS_INVALID_PARAMS;
    }
    if (!amiibo_store_load(commands->amiibo, &request->payload[LOAD_HEADER_SIZE], size)) {
        return HOST_STATUS_AMIIBO_ERROR;
    }
    reply_uid(commands);
    return HOST_STATUS_OK;
}

uint8_t host_handle_amiibo_load_start(host_commands_t *commands, const host_request_t *request) {
    if (request->payload_length < LOAD_HEADER_SIZE) {
        return HOST_STATUS_INVALID_PARAMS;
    }
    if (!amiibo_store_begin(commands->amiibo, read_u16(request->payload))) {
        return HOST_STATUS_AMIIBO_ERROR;
    }
    commands->reply[0] = AMIIBO_CHUNK_SIZE;
    commands->reply_length = 1;
    return HOST_STATUS_OK;
}

uint8_t host_handle_amiibo_load_chunk(host_commands_t *commands, const host_request_t *request) {
    if (request->payload_length <= CHUNK_HEADER_SIZE) {
        return HOST_STATUS_INVALID_PARAMS;
    }
    bool accepted = amiibo_store_add_chunk(commands->amiibo, request->payload[0], &request->payload[CHUNK_HEADER_SIZE],
                                           request->payload_length - CHUNK_HEADER_SIZE);
    return accepted ? HOST_STATUS_OK : HOST_STATUS_INVALID_PARAMS;
}

uint8_t host_handle_amiibo_load_finish(host_commands_t *commands, const host_request_t *request) {
    (void)request;
    if (!amiibo_store_finish(commands->amiibo)) {
        return HOST_STATUS_INVALID_PARAMS;
    }
    reply_uid(commands);
    return HOST_STATUS_OK;
}

uint8_t host_handle_amiibo_clear(host_commands_t *commands, const host_request_t *request) {
    (void)request;
    amiibo_store_clear(commands->amiibo);
    return HOST_STATUS_OK;
}
