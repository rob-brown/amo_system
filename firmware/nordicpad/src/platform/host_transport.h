#ifndef PLATFORM_HOST_TRANSPORT_H
#define PLATFORM_HOST_TRANSPORT_H

#include <stddef.h>
#include <stdint.h>

typedef void (*host_receive_fn)(void *context, const uint8_t *data, size_t length);

typedef struct {
    void (*start)(void *context, host_receive_fn on_receive, void *receive_context);
    void (*write)(void *context, const uint8_t *data, size_t length);
    void *context;
} host_transport_t;

#endif
