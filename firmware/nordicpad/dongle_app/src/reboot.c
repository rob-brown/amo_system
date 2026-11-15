#include "reboot.h"

#include <zephyr/devicetree.h>
#include <zephyr/drivers/flash.h>
#include <zephyr/kernel.h>
#include <zephyr/linker/linker-defs.h>
#include <zephyr/sys/reboot.h>

#include "platform/log.h"

#define REBOOT_DELAY_MS 300
#define ERASE_SIZE 4096

static host_reboot_target_t pending_target;

static const struct device *flash_device(void) {
    return DEVICE_DT_GET(DT_CHOSEN(zephyr_flash_controller));
}

static void invalidate_application(void) {
    uintptr_t last_byte = (uintptr_t)__rom_region_start + (uintptr_t)_flash_used - 1;
    off_t page = (off_t)(last_byte & ~((uintptr_t)ERASE_SIZE - 1));

    int result = flash_erase(flash_device(), page, ERASE_SIZE);
    LOG("erased image page 0x%lx for the bootloader: %d", (unsigned long)page, result);
}

static void perform_reboot(struct k_work *work) {
    (void)work;
    if (pending_target == HOST_REBOOT_BOOTLOADER) {
        invalidate_application();
    }
    sys_reboot(SYS_REBOOT_COLD);
}

static K_WORK_DELAYABLE_DEFINE(reboot_work, perform_reboot);

void dongle_reboot(void *context, host_reboot_target_t target) {
    (void)context;
    pending_target = target;
    k_work_schedule(&reboot_work, K_MSEC(REBOOT_DELAY_MS));
}
