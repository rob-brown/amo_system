#ifndef BLE_BLE_DIAGNOSTICS_H
#define BLE_BLE_DIAGNOSTICS_H

#include <stdint.h>

#include "btstack.h"

void ble_diagnostics_on_ready(void);
void ble_diagnostics_on_connected(hci_con_handle_t connection);
void ble_diagnostics_on_encrypted(hci_con_handle_t connection);
void ble_diagnostics_on_disconnected(void);
void ble_diagnostics_on_hci_event(const uint8_t *packet);

#endif
