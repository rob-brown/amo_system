#ifndef BLE_BLE_PERIPHERAL_H
#define BLE_BLE_PERIPHERAL_H

#include <stdbool.h>
#include <stdint.h>

#include "ble/ble_link_key.h"
#include "ble/gatt_bridge.h"
#include "controller/profile.h"

#define BLE_ADDRESS_SIZE 6

typedef struct {
    void (*on_ready)(void *context, const uint8_t local_address_le[BLE_ADDRESS_SIZE]);
    void (*on_connected)(void *context);
    void (*on_disconnected)(void *context);
    void (*on_interval_changed)(void *context, uint16_t interval_units);
    void *context;
} ble_peripheral_listener_t;

typedef struct {
    void (*power_on)(const controller_profile_t *profile);
    void (*select_address)(const controller_profile_t *profile, uint8_t address[BLE_ADDRESS_SIZE]);
} ble_platform_t;

typedef struct {
    bool (*provide)(void *context, uint8_t address_le[BLE_ADDRESS_SIZE]);
    void *context;
} ble_host_address_provider_t;

typedef struct {
    const controller_profile_t *profile;
    ble_platform_t platform;
    ble_peripheral_listener_t listener;
    ble_link_key_provider_t link_keys;
    ble_host_address_provider_t host_address;
    gatt_bridge_listener_t gatt;
} ble_peripheral_config_t;

int ble_peripheral_start(const ble_peripheral_config_t *config);

#endif
