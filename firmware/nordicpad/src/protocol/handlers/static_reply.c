#include "protocol/handlers/static_reply.h"

#include <string.h>

#include "controller/identity.h"

size_t static_reply_handle(void *context,
                           const command_request_t *request,
                           uint8_t *payload,
                           size_t capacity) {
    (void)request;
    const static_reply_t *reply = context;

    if (reply->payload_length > capacity) {
        return 0;
    }

    if (reply->payload_length > 0) {
        memcpy(payload, reply->payload, reply->payload_length);
    }
    return reply->payload_length;
}
