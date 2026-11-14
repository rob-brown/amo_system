#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "app/app.h"
#include "btstack.h"
#include "btstack_memory.h"
#include "btstack_run_loop_posix.h"
#include "btstack_signal.h"
#include "btstack_uart.h"
#include "hci_dump_posix_fs.h"
#include "hci_transport_h4.h"
#include "platform/log.h"
#include "platform/mac_ble_platform.h"
#include "platform/mac_pty_transport.h"
#include "platform/zephyr_chipset.h"
#include "storage/file_pairing_store.h"

#define HCI_LOG_PATH "/tmp/nordicpad_hci.pklg"
#ifdef NORDICPAD_PRO_CONTROLLER
#define PAIRING_FILE_NAME ".nordicpad_pro_pairing.bin"
#else
#define PAIRING_FILE_NAME ".nordicpad_pairing.bin"
#endif
#define HOST_CHANNEL_LINK_NAME ".nordicpad.tty"
#define DEFAULT_BAUD_RATE 1000000
#define SHUT_DOWN_TIMEOUT_MS 3000

static hci_transport_config_uart_t uart_config = {
    HCI_TRANSPORT_CONFIG_UART,
    DEFAULT_BAUD_RATE,
    0,
    0,
    NULL,
};

static btstack_packet_callback_registration_t state_callback;
static btstack_timer_source_t shut_down_deadline;

static void exit_now(btstack_timer_source_t *timer) {
    UNUSED(timer);
    LOG("shut down timed out");
    exit(0);
}

static void on_state_event(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size) {
    UNUSED(channel);
    UNUSED(size);

    if (packet_type != HCI_EVENT_PACKET || hci_event_packet_get_type(packet) != BTSTACK_EVENT_STATE) {
        return;
    }
    if (btstack_event_state_get_state(packet) == HCI_STATE_OFF) {
        LOG("controller released");
        exit(0);
    }
}

static void shut_down(void) {
    LOG("shutting down");
    btstack_run_loop_set_timer_handler(&shut_down_deadline, exit_now);
    btstack_run_loop_set_timer(&shut_down_deadline, SHUT_DOWN_TIMEOUT_MS);
    btstack_run_loop_add_timer(&shut_down_deadline);
    hci_power_control(HCI_POWER_OFF);
}

static void interrupt_self(int signal_number) {
    UNUSED(signal_number);
    kill(getpid(), SIGINT);
}

static void forward_to_interrupt(int signal_number) {
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = interrupt_self;
    sigemptyset(&action.sa_mask);
    sigaction(signal_number, &action, NULL);
}

static void open_hci_log(void) {
    hci_dump_posix_fs_open(HCI_LOG_PATH, HCI_DUMP_PACKETLOGGER);
    hci_dump_init(hci_dump_posix_fs_get_instance());
    LOG("HCI log: %s", HCI_LOG_PATH);
}

static void init_controller(const char *device) {
    uart_config.device_name = device;
    LOG("controller: %s", device);

    const hci_transport_t *transport = hci_transport_h4_instance_for_uart(btstack_uart_posix_instance());
    hci_init(transport, &uart_config);
    hci_set_chipset(zephyr_chipset_with_public_address());
}

int main(int argc, const char *argv[]) {
    if (argc != 3 || strcmp(argv[1], "-u") != 0) {
        LOG("usage: %s -u /dev/cu.usbmodemXXXX", argv[0]);
        return 1;
    }

    setvbuf(stdout, NULL, _IOLBF, 0);
    btstack_memory_init();
    btstack_run_loop_init(btstack_run_loop_posix_get_instance());
    open_hci_log();
    init_controller(argv[2]);
    state_callback.callback = on_state_event;
    hci_add_event_handler(&state_callback);
    btstack_signal_register_callback(SIGINT, (void (*)(void))shut_down);
    forward_to_interrupt(SIGTERM);
    forward_to_interrupt(SIGHUP);

    char pairing_path[FILE_PAIRING_STORE_PATH_MAX];
    snprintf(pairing_path, sizeof(pairing_path), "%s/%s", getenv("HOME"), PAIRING_FILE_NAME);
    file_pairing_store_t pairing_store;
    file_pairing_store_init(&pairing_store, pairing_path);

    char host_link_path[FILE_PAIRING_STORE_PATH_MAX];
    snprintf(host_link_path, sizeof(host_link_path), "%s/%s", getenv("HOME"), HOST_CHANNEL_LINK_NAME);
    mac_pty_transport_t host_transport;
    if (mac_pty_transport_open(&host_transport, host_link_path) != 0) {
        LOG("could not open the host channel");
        return 1;
    }

    const app_platform_t platform = {
        .pairing_store = &pairing_store.store,
        .ble = MAC_BLE_PLATFORM,
        .host = mac_pty_transport_interface(&host_transport),
    };
    return app_run(&platform);
}
