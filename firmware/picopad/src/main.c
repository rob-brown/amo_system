#include <stdio.h>
#include <string.h>
#include "pico/stdlib.h"
#include "pico/bootrom.h"
#include "pico/cyw43_arch.h"
#include "hardware/watchdog.h"
#include "btstack.h"

#include "bt_hid.h"
#include "bonding_storage.h"
#include "logging.h"
#include "reconnect_manager.h"
#include "controller_state.h"
#include "host_protocol.h"
#include "spi_flash_data.h"

#define LED_BLINK_MS 500
#define HOST_POLL_INTERVAL_MS 1
#define AMIIBO_BUFFER_SIZE 2048
#define MAX_PENDING_BUTTONS 8

static controller_state_t controller;
static host_protocol_t host_proto;
static uint8_t amiibo_buffer[AMIIBO_BUFFER_SIZE];

static bool is_connected = false;
static bool btstack_ready = false;

static btstack_timer_source_t led_timer;
static btstack_timer_source_t host_poll_timer;
static bool led_state = false;
static host_led_mode_t led_mode = HOST_LED_AUTO;

static btstack_packet_callback_registration_t sm_event_callback_registration;

typedef struct {
    btstack_timer_source_t timer;
    button_t button;
    bool active;
} pending_button_t;

static pending_button_t pending_buttons[MAX_PENDING_BUTTONS];

static const button_t button_id_map[] = {
    BTN_A,        // 0x00
    BTN_B,        // 0x01
    BTN_X,        // 0x02
    BTN_Y,        // 0x03
    BTN_L,        // 0x04
    BTN_R,        // 0x05
    BTN_ZL,       // 0x06
    BTN_ZR,       // 0x07
    BTN_UP,       // 0x08
    BTN_DOWN,     // 0x09
    BTN_LEFT,     // 0x0A
    BTN_RIGHT,    // 0x0B
    BTN_PLUS,     // 0x0C
    BTN_MINUS,    // 0x0D
    BTN_HOME,     // 0x0E
    BTN_CAPTURE,  // 0x0F
    BTN_L_STICK,  // 0x10
    BTN_R_STICK   // 0x11
};

static void update_led(void) {
    switch (led_mode) {
        case HOST_LED_OFF:
            cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
            break;
        case HOST_LED_ON:
            cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
            break;
        case HOST_LED_BLINK_SLOW:
        case HOST_LED_BLINK_FAST:
        case HOST_LED_AUTO:
            cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, led_state);
            break;
    }
}

static void led_timer_handler(btstack_timer_source_t *ts) {
    led_state = !led_state;
    update_led();

    uint32_t interval;
    switch (led_mode) {
        case HOST_LED_BLINK_SLOW:
            interval = 1000;
            break;
        case HOST_LED_BLINK_FAST:
            interval = 200;
            break;
        case HOST_LED_AUTO:
        default:
            interval = is_connected ? 2000 : 500;
            break;
    }

    btstack_run_loop_set_timer(ts, interval);
    btstack_run_loop_add_timer(ts);
}

static void start_led_blink(void) {
    btstack_run_loop_set_timer_handler(&led_timer, led_timer_handler);
    btstack_run_loop_set_timer(&led_timer, LED_BLINK_MS);
    btstack_run_loop_add_timer(&led_timer);
}

static void connection_callback(bool connected) {
    is_connected = connected;

    bd_addr_t addr;
    if (connected) {
        gap_local_bd_addr(addr);
        host_protocol_set_connection_state(&host_proto, HOST_CONN_READY, addr);
        host_protocol_send_event_connection(&host_proto, HOST_CONN_READY, addr);
    } else {
        host_protocol_set_connection_state(&host_proto, HOST_CONN_DISCONNECTED, NULL);
        host_protocol_send_event_connection(&host_proto, HOST_CONN_DISCONNECTED, NULL);

        if (bt_hid_get_bonding_status(NULL)) {
            pico_log_notice("Disconnected from bonded device, attempting auto-reconnect");
            if (bonding_storage_load_last_connected(addr)) {
                reconnect_policy_t policy = {
                    .type = RECONNECT_POLICY_AUTO,
                    .max_attempts = 3,
                    .base_interval_ms = 2000,
                    .use_exponential_backoff = true
                };

                sleep_ms(2000);

                bt_hid_reconnect(addr, policy);
            }
        }
    }

    update_led();
}

static void host_start_advertising(void) {
    bt_hid_start_advertising();
    host_protocol_set_connection_state(&host_proto, HOST_CONN_ADVERTISING, NULL);
}

static void host_stop_advertising(void) {
    bt_hid_stop_advertising();
    host_protocol_set_connection_state(&host_proto, HOST_CONN_DISCONNECTED, NULL);
}

static void host_disconnect(void) {
    bt_hid_disconnect();
}

static void host_set_led(host_led_mode_t mode) {
    led_mode = mode;
    update_led();
}

static void host_reset(bool bootloader) {
    if (bootloader) {
        reset_usb_boot(0, 0);
    } else {
        watchdog_reboot(0, 0, 0);
    }
}

static void host_send(const uint8_t *data, size_t len) {
    for (size_t i = 0; i < len; i++) {
        putchar_raw(data[i]);
    }
    stdio_flush();
}

static void button_release_timer_handler(btstack_timer_source_t *ts) {
    for (int i = 0; i < MAX_PENDING_BUTTONS; i++) {
        if (&pending_buttons[i].timer == ts && pending_buttons[i].active) {
            controller_set_button(&controller, pending_buttons[i].button, false);
            pending_buttons[i].active = false;
            break;
        }
    }
}

static void host_press_button(uint8_t button_id, uint16_t duration_ms) {
    if (button_id > 0x11) {
        return;
    }

    button_t button = button_id_map[button_id];
    controller_set_button(&controller, button, true);

    if (duration_ms == 0) {
        duration_ms = 50;
    }

    for (int i = 0; i < MAX_PENDING_BUTTONS; i++) {
        if (!pending_buttons[i].active) {
            pending_buttons[i].active = true;
            pending_buttons[i].button = button;
            btstack_run_loop_set_timer_handler(&pending_buttons[i].timer, button_release_timer_handler);
            btstack_run_loop_set_timer(&pending_buttons[i].timer, duration_ms);
            btstack_run_loop_add_timer(&pending_buttons[i].timer);
            break;
        }
    }
}

static void host_amiibo_loaded(const uint8_t *data, uint16_t size) {
    switch_protocol_t *proto = bt_hid_get_protocol();
    if (proto != NULL) {
        switch_protocol_set_amiibo(proto, data, size);
    }
}

static void host_amiibo_cleared(void) {
    switch_protocol_t *proto = bt_hid_get_protocol();
    if (proto != NULL) {
        switch_protocol_clear_amiibo(proto);
    }
}

static void host_get_mcu_state(uint8_t *mcu_state, uint8_t *nfc_state, uint8_t *input_mode, uint8_t *amiibo_loaded,
                               uint8_t *last_report_id, uint8_t *last_mcu_cmd, uint8_t *last_mcu_subcmd, uint16_t *mcu_req_count) {
    switch_protocol_t *proto = bt_hid_get_protocol();
    if (proto != NULL) {
        *mcu_state = proto->mcu_state;
        *nfc_state = proto->nfc_state;
        *input_mode = proto->input_report_mode;
        *amiibo_loaded = proto->amiibo_loaded ? 1 : 0;
        *last_report_id = proto->last_output_report_id;
        *last_mcu_cmd = proto->last_mcu_cmd;
        *last_mcu_subcmd = proto->last_mcu_subcmd;
        *mcu_req_count = proto->mcu_request_count;
    }
}

static void host_get_mcu_debug(uint8_t *last_request, uint8_t *last_response) {
    switch_protocol_t *proto = bt_hid_get_protocol();
    if (proto != NULL) {
        memcpy(last_request, proto->last_mcu_request, 16);
        memcpy(last_response, proto->last_mcu_response, 24);
    }
}

static void host_poll_timer_handler(btstack_timer_source_t *ts) {
    int c;
    while ((c = getchar_timeout_us(0)) != PICO_ERROR_TIMEOUT) {
        host_protocol_rx_byte(&host_proto, (uint8_t)c);
    }

    if (is_connected) {
        switch_protocol_t *proto = bt_hid_get_protocol();
        if (proto != NULL) {
            uint8_t player = switch_protocol_get_player_number(proto);
            if (player != host_proto.player_number) {
                host_protocol_set_player_number(&host_proto, player);
            }
        }
    }

    btstack_run_loop_set_timer(ts, HOST_POLL_INTERVAL_MS);
    btstack_run_loop_add_timer(ts);
}

static void start_host_poll_timer(void) {
    btstack_run_loop_set_timer_handler(&host_poll_timer, host_poll_timer_handler);
    btstack_run_loop_set_timer(&host_poll_timer, HOST_POLL_INTERVAL_MS);
    btstack_run_loop_add_timer(&host_poll_timer);
}

static void packet_handler(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size) {
    UNUSED(channel);
    UNUSED(size);

    if (packet_type != HCI_EVENT_PACKET) return;

    switch (hci_event_packet_get_type(packet)) {
        case BTSTACK_EVENT_STATE:
            if (btstack_event_state_get_state(packet) == HCI_STATE_WORKING) {
                btstack_ready = true;

                bd_addr_t local_addr;
                gap_local_bd_addr(local_addr);

                start_led_blink();
                start_host_poll_timer();

                bd_addr_t bonded_addr;
                if (bt_hid_get_bonding_status(&bonded_addr)) {
                    pico_log_noticef("Found bonded device %s, attempting reconnection", bd_addr_to_str(bonded_addr));

                    reconnect_policy_t policy = {
                        .type = RECONNECT_POLICY_BOOT,
                        .max_attempts = 1,
                        .base_interval_ms = 0,
                        .use_exponential_backoff = false
                    };

                    bt_hid_reconnect(bonded_addr, policy);

                    host_protocol_set_connection_state(&host_proto, HOST_CONN_DISCONNECTED, NULL);
                } else {
                    pico_log_notice("No bonded device found, staying idle");
                    host_protocol_set_connection_state(&host_proto, HOST_CONN_DISCONNECTED, NULL);
                }
            }
            break;
        default:
            break;
    }
}

int main(void) {
    stdio_init_all();

    sleep_ms(1000);

    if (cyw43_arch_init()) {
        return -1;
    }

    spi_flash_init();

    controller_state_init(&controller, CONTROLLER_PRO);

    memset(pending_buttons, 0, sizeof(pending_buttons));

    host_protocol_init(&host_proto, &controller);
    logging_init(&host_proto);
    host_protocol_set_callbacks(
        &host_proto,
        host_start_advertising,
        host_stop_advertising,
        host_disconnect,
        host_set_led,
        host_reset,
        host_send,
        host_press_button
    );
    host_protocol_set_amiibo_buffer(&host_proto, amiibo_buffer, AMIIBO_BUFFER_SIZE);
    host_protocol_set_amiibo_callbacks(&host_proto, host_amiibo_loaded, host_amiibo_cleared);
    host_protocol_set_mcu_state_callback(&host_proto, host_get_mcu_state);
    host_protocol_set_mcu_debug_callback(&host_proto, host_get_mcu_debug);

    bt_hid_init(&controller, connection_callback);

    sm_event_callback_registration.callback = &packet_handler;
    hci_add_event_handler(&sm_event_callback_registration);

    hci_power_control(HCI_POWER_ON);

    btstack_run_loop_execute();

    return 0;
}
