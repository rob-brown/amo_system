#ifndef BT_HID_H
#define BT_HID_H

#include <stdint.h>
#include <stdbool.h>
#include "btstack.h"
#include "reconnect_manager.h"
#include "switch_protocol.h"
#include "controller_state.h"

#define L2CAP_PSM_HID_CONTROL   0x0011
#define L2CAP_PSM_HID_INTERRUPT 0x0013

#define BT_DEVICE_CLASS_GAMEPAD 0x002508

typedef enum {
    BT_HID_STATE_IDLE,
    BT_HID_STATE_ADVERTISING,
    BT_HID_STATE_RECONNECTING,
    BT_HID_STATE_CONTROL_CONNECTED,
    BT_HID_STATE_INTERRUPT_CONNECTED,
    BT_HID_STATE_READY
} bt_hid_state_t;

typedef enum {
    BT_HID_MODE_SERVER,
    BT_HID_MODE_CLIENT
} bt_hid_mode_t;

typedef void (*bt_hid_connection_callback_t)(bool connected);

void bt_hid_init(controller_state_t *controller, bt_hid_connection_callback_t callback);

void bt_hid_start_advertising(void);
void bt_hid_stop_advertising(void);

void bt_hid_disconnect(void);

bool bt_hid_reconnect(bd_addr_t addr, reconnect_policy_t policy);
void bt_hid_clear_bonding(void);
bool bt_hid_get_bonding_status(bd_addr_t *addr);

bool bt_hid_send_report(void);

bt_hid_state_t bt_hid_get_state(void);
bool bt_hid_is_connected(void);

void bt_hid_process(void);

switch_protocol_t *bt_hid_get_protocol(void);

#endif
