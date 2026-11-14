#ifndef BLE_BLE_LINK_KEY_H
#define BLE_BLE_LINK_KEY_H

#include <stdbool.h>
#include <stdint.h>

#define BLE_LINK_KEY_SIZE 16

typedef bool (*ble_link_key_provider_fn)(void *context, uint8_t link_key[BLE_LINK_KEY_SIZE]);

typedef struct {
    ble_link_key_provider_fn provide;
    void *context;
} ble_link_key_provider_t;

void ble_link_key_answer_request(const uint8_t *hci_event, const ble_link_key_provider_t *provider);

#endif
