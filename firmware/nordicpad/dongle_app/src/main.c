#include <zephyr/kernel.h>
#include <zephyr/usb/usb_device.h>

#include "app/app.h"
#include "btstack.h"
#include "btstack_memory.h"
#include "platform/mac_ble_platform.h"
#include "platform/zephyr_cdc_transport.h"
#include "platform/zephyr_chipset.h"
#include "platform/zephyr_hci_transport.h"
#include "platform/zephyr_run_loop.h"
#include "reboot.h"
#include "storage/zephyr_flash_pairing_store.h"

#ifdef NORDICPAD_DONGLE_HCI_DUMP
#include "hci_dump_embedded_stdout.h"
#endif

#define CONSOLE_ATTACH_DELAY_MS 4000

void bt_ctlr_assert_handle(char *file, uint32_t line) {
    printk("controller assert: %s:%u\n", file, line);
    while (true) {
    }
}

int main(void) {
    usb_enable(NULL);
    k_msleep(CONSOLE_ATTACH_DELAY_MS);

    btstack_memory_init();
    btstack_run_loop_init(zephyr_run_loop_instance());
#ifdef NORDICPAD_DONGLE_HCI_DUMP
    hci_dump_init(hci_dump_embedded_stdout_get_instance());
#endif
    hci_init(zephyr_hci_transport_instance(), NULL);
    hci_set_chipset(zephyr_chipset_with_public_address());

    static zephyr_cdc_transport_t host_channel;
    zephyr_cdc_transport_init(&host_channel, DEVICE_DT_GET(DT_NODELABEL(host_channel)));

    const app_platform_t platform = {
        .pairing_store = zephyr_flash_pairing_store(),
        .ble = MAC_BLE_PLATFORM,
        .host = zephyr_cdc_transport_interface(&host_channel),
        .system = {dongle_reboot, NULL},
    };
    return app_run(&platform);
}
