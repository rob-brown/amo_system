#ifndef BLE_GATT_BRIDGE_H
#define BLE_GATT_BRIDGE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "btstack.h"

typedef void (*gatt_command_write_fn)(void *context, const uint8_t *value, size_t length);

typedef struct {
    gatt_command_write_fn on_command_write;
    void *context;
} gatt_bridge_listener_t;

void gatt_bridge_init(const gatt_bridge_listener_t *listener);

void gatt_bridge_connected(hci_con_handle_t connection);

void gatt_bridge_disconnected(void);

bool gatt_bridge_send_reply(const uint8_t *frame, size_t length);

bool gatt_bridge_input_enabled(void);

bool gatt_bridge_send_input_report(const uint8_t *report, size_t length);

uint16_t gatt_bridge_read(hci_con_handle_t connection,
                          uint16_t attribute_handle,
                          uint16_t offset,
                          uint8_t *buffer,
                          uint16_t buffer_size);

int gatt_bridge_write(hci_con_handle_t connection,
                      uint16_t attribute_handle,
                      uint16_t transaction_mode,
                      uint16_t offset,
                      uint8_t *buffer,
                      uint16_t buffer_size);

void gatt_bridge_handle_att_event(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size);

#endif
