#ifndef JOYCON_CLIENT_H
#define JOYCON_CLIENT_H

#include <stdint.h>
#include <stdbool.h>
#include "btstack.h"

#define L2CAP_PSM_HID_CONTROL   0x0011
#define L2CAP_PSM_HID_INTERRUPT 0x0013

typedef enum {
    JOYCON_STATE_IDLE,
    JOYCON_STATE_DISCOVERED,
    JOYCON_STATE_CONTROL_CONNECTING,
    JOYCON_STATE_CONTROL_CONNECTED,
    JOYCON_STATE_INTERRUPT_CONNECTING,
    JOYCON_STATE_READY
} joycon_state_t;

typedef void (*joycon_data_callback_t)(uint8_t *data, uint16_t size);
typedef void (*joycon_state_callback_t)(joycon_state_t state);

void joycon_client_init(void);
void joycon_client_set_packet_handler(btstack_packet_handler_t handler);
void joycon_client_set_data_callback(joycon_data_callback_t callback);
void joycon_client_set_state_callback(joycon_state_callback_t callback);

bool joycon_client_connect(bd_addr_t addr);
void joycon_client_disconnect(void);
joycon_state_t joycon_client_get_state(void);
bool joycon_client_is_connected(void);

bool joycon_client_send_data(const uint8_t *data, uint16_t size);

void joycon_client_get_addr(bd_addr_t addr);

#endif
