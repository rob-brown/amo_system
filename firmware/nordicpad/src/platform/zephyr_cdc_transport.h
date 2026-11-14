#ifndef PLATFORM_ZEPHYR_CDC_TRANSPORT_H
#define PLATFORM_ZEPHYR_CDC_TRANSPORT_H

#include <zephyr/device.h>

#include "btstack_run_loop.h"
#include "platform/host_transport.h"

typedef struct {
    const struct device *device;
    btstack_timer_source_t poll_timer;
    host_receive_fn on_receive;
    void *receive_context;
} zephyr_cdc_transport_t;

void zephyr_cdc_transport_init(zephyr_cdc_transport_t *transport, const struct device *device);
host_transport_t zephyr_cdc_transport_interface(zephyr_cdc_transport_t *transport);

#endif
