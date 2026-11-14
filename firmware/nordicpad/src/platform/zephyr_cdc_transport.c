#include "platform/zephyr_cdc_transport.h"

#include <zephyr/drivers/uart.h>

#define POLL_INTERVAL_MS 2
#define READ_BUFFER_SIZE 256

static void poll_receive(btstack_timer_source_t *timer) {
    zephyr_cdc_transport_t *transport = btstack_run_loop_get_timer_context(timer);
    uint8_t buffer[READ_BUFFER_SIZE];
    size_t count = 0;
    unsigned char byte;

    while (count < sizeof(buffer) && uart_poll_in(transport->device, &byte) == 0) {
        buffer[count++] = byte;
    }
    if (count > 0 && transport->on_receive != NULL) {
        transport->on_receive(transport->receive_context, buffer, count);
    }
    btstack_run_loop_set_timer(timer, POLL_INTERVAL_MS);
    btstack_run_loop_add_timer(timer);
}

static void start(void *context, host_receive_fn on_receive, void *receive_context) {
    zephyr_cdc_transport_t *transport = context;
    transport->on_receive = on_receive;
    transport->receive_context = receive_context;

    btstack_run_loop_set_timer_handler(&transport->poll_timer, poll_receive);
    btstack_run_loop_set_timer_context(&transport->poll_timer, transport);
    btstack_run_loop_set_timer(&transport->poll_timer, POLL_INTERVAL_MS);
    btstack_run_loop_add_timer(&transport->poll_timer);
}

static void write_bytes(void *context, const uint8_t *data, size_t length) {
    zephyr_cdc_transport_t *transport = context;

    for (size_t index = 0; index < length; index++) {
        uart_poll_out(transport->device, data[index]);
    }
}

void zephyr_cdc_transport_init(zephyr_cdc_transport_t *transport, const struct device *device) {
    transport->device = device;
    transport->on_receive = NULL;
    transport->receive_context = NULL;
}

host_transport_t zephyr_cdc_transport_interface(zephyr_cdc_transport_t *transport) {
    return (host_transport_t){start, write_bytes, transport};
}
