#ifndef PROTOCOL_COMMAND_SESSION_H
#define PROTOCOL_COMMAND_SESSION_H

#include <stddef.h>
#include <stdint.h>

#include "protocol/command_set.h"

typedef enum {
    COMMAND_OUTCOME_REPLIED,
    COMMAND_OUTCOME_MALFORMED,
    COMMAND_OUTCOME_UNKNOWN,
    COMMAND_OUTCOME_REPLY_TOO_LARGE,
} command_outcome_status_t;

typedef struct {
    command_outcome_status_t status;
    uint8_t command;
    uint8_t subcommand;
} command_outcome_t;

typedef struct {
    const command_set_t *set;
    size_t prefix_size;
} command_session_t;

void command_session_init(command_session_t *session, const command_set_t *set, size_t prefix_size);

size_t command_session_handle(const command_session_t *session,
                              const uint8_t *value,
                              size_t value_length,
                              uint8_t *reply,
                              size_t reply_capacity,
                              command_outcome_t *outcome);

#endif
