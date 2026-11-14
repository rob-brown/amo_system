#include "app/app.h"
#include "pico/cyw43_arch.h"
#include "pico/stdlib.h"
#include "platform/log.h"
#include "platform/pico_ble_platform.h"
#include "storage/flash_pairing_store.h"

#define USB_CONNECT_TIMEOUT_MS 15000
#define USB_POLL_MS 100

static void wait_for_usb_host(void) {
    for (uint32_t waited = 0; waited < USB_CONNECT_TIMEOUT_MS && !stdio_usb_connected(); waited += USB_POLL_MS) {
        sleep_ms(USB_POLL_MS);
    }
    sleep_ms(500);
}

int main(void) {
    stdio_init_all();
    wait_for_usb_host();

    if (cyw43_arch_init() != 0) {
        LOG("cyw43 init failed");
        return -1;
    }

    const app_platform_t platform = {
        .pairing_store = flash_pairing_store(),
        .ble = PICO_BLE_PLATFORM,
    };
    return app_run(&platform);
}
