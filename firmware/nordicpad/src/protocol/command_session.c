#include "protocol/command_session.h"

#include "protocol/command_frame.h"

#define MAX_REPLY_PAYLOAD 512

void command_session_init(command_session_t *session, const command_set_t *set, size_t prefix_size) {
    session->set = set;
    session->prefix_size = prefix_size;
}

static size_t reject(command_outcome_t *outcome, command_outcome_status_t status) {
    outcome->status = status;
    return 0;
}

size_t command_session_handle(const command_session_t *session,
                              const uint8_t *value,
                              size_t value_length,
                              uint8_t *reply,
                              size_t reply_capacity,
                              command_outcome_t *outcome) {
    command_request_t request;
    outcome->command = 0;
    outcome->subcommand = 0;

    command_frame_status_t parsed = command_frame_parse_request(value, value_length, session->prefix_size, &request);
    if (parsed != COMMAND_FRAME_OK && session->prefix_size != COMMAND_BASIC_PREFIX_SIZE) {
        parsed = command_frame_parse_request(value, value_length, COMMAND_BASIC_PREFIX_SIZE, &request);
    }
    if (parsed != COMMAND_FRAME_OK) {
        return reject(outcome, COMMAND_OUTCOME_MALFORMED);
    }
    outcome->command = request.command;
    outcome->subcommand = request.subcommand;

    uint8_t payload[MAX_REPLY_PAYLOAD];
    size_t payload_length = 0;
    if (command_router_dispatch(&session->set->router, &request, payload, sizeof(payload), &payload_length) !=
        COMMAND_ROUTER_HANDLED) {
        return reject(outcome, COMMAND_OUTCOME_UNKNOWN);
    }

    size_t reply_length = command_frame_build_reply(&request, payload, payload_length, reply, reply_capacity);
    if (reply_length == 0) {
        return reject(outcome, COMMAND_OUTCOME_REPLY_TOO_LARGE);
    }

    outcome->status = COMMAND_OUTCOME_REPLIED;
    return reply_length;
}
