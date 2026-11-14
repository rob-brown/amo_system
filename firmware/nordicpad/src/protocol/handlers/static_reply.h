#ifndef PROTOCOL_HANDLERS_STATIC_REPLY_H
#define PROTOCOL_HANDLERS_STATIC_REPLY_H

#include <stddef.h>
#include <stdint.h>

#include "protocol/command_frame.h"

size_t static_reply_handle(void *context,
                           const command_request_t *request,
                           uint8_t *payload,
                           size_t capacity);

#endif
