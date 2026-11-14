#include "reboot.h"

#include <hal/nrf_power.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/reboot.h>

#define BOOTLOADER_DFU_START 0xB1
#define REBOOT_DELAY_MS 300

static host_reboot_target_t pending_target;

static void perform_reboot(struct k_work *work) {
    (void)work;
    if (pending_target == HOST_REBOOT_BOOTLOADER) {
        nrf_power_gpregret_set(NRF_POWER, 0, BOOTLOADER_DFU_START);
    }
    sys_reboot(SYS_REBOOT_COLD);
}

static K_WORK_DELAYABLE_DEFINE(reboot_work, perform_reboot);

void dongle_reboot(void *context, host_reboot_target_t target) {
    (void)context;
    pending_target = target;
    k_work_schedule(&reboot_work, K_MSEC(REBOOT_DELAY_MS));
}
