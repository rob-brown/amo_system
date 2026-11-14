#ifndef PROTOCOL_HANDLERS_MEMORY_READ_H
#define PROTOCOL_HANDLERS_MEMORY_READ_H

#include <stddef.h>
#include <stdint.h>

#include "protocol/command_frame.h"

#define MEMORY_READ_COMMAND 0x02
#define MEMORY_READ_SUBCOMMAND 0x04

size_t memory_read_handle(void *context,
                          const command_request_t *request,
                          uint8_t *payload,
                          size_t capacity);

#endif
