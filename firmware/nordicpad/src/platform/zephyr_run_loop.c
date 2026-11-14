#include "platform/zephyr_run_loop.h"

#include <zephyr/kernel.h>

#include "platform/zephyr_hci_transport.h"

static uint32_t get_time_ms(void) {
    return k_uptime_get_32();
}

static void set_timer(btstack_timer_source_t *timer, uint32_t timeout_ms) {
    timer->timeout = k_uptime_get_32() + 1 + timeout_ms;
}

static void init(void) {
    btstack_run_loop_base_init();
}

static k_timeout_t wait_until_next_timer(uint32_t now) {
    k_timeout_t timeout;
    timeout.ticks = btstack_run_loop_base_get_time_until_timeout(now);
    if (timeout.ticks < 0) {
        timeout.ticks = K_TICKS_FOREVER;
    }
    return timeout;
}

static void execute(void) {
    while (true) {
        uint32_t now = k_uptime_get_32();
        btstack_run_loop_base_process_timers(now);

        struct net_buf *buffer = k_fifo_get(zephyr_hci_transport_rx_queue(), wait_until_next_timer(now));
        if (buffer != NULL) {
            zephyr_hci_transport_deliver(buffer);
        }
    }
}

static const btstack_run_loop_t run_loop = {
    &init,
    NULL,
    NULL,
    NULL,
    NULL,
    &set_timer,
    &btstack_run_loop_base_add_timer,
    &btstack_run_loop_base_remove_timer,
    &execute,
    &btstack_run_loop_base_dump_timer,
    &get_time_ms,
};

const btstack_run_loop_t *zephyr_run_loop_instance(void) {
    return &run_loop;
}
