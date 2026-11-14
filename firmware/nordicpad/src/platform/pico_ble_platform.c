#include "platform/pico_ble_platform.h"

#include "btstack.h"

static void power_on(const controller_profile_t *profile) {
    hci_power_control(HCI_POWER_ON);
    hci_set_bd_addr((uint8_t *)profile->address);
}

static void select_address(const controller_profile_t *profile, uint8_t address[BLE_ADDRESS_SIZE]) {
    (void)profile;
    gap_local_bd_addr(address);
}

const ble_platform_t PICO_BLE_PLATFORM = {
    .power_on = power_on,
    .select_address = select_address,
};
