#ifndef SWITCH_PROTOCOL_H
#define SWITCH_PROTOCOL_H

#include <stdint.h>
#include <stdbool.h>
#include "controller_state.h"

#define HID_REPORT_INPUT  0xA1
#define HID_REPORT_OUTPUT 0xA2

#define INPUT_REPORT_ID_SUBCOMMAND 0x21
#define INPUT_REPORT_ID_IMU        0x30
#define INPUT_REPORT_ID_MCU        0x31
#define INPUT_REPORT_ID_SIMPLE     0x3F

#define OUTPUT_REPORT_ID_SUBCOMMAND  0x01
#define OUTPUT_REPORT_ID_RUMBLE      0x10
#define OUTPUT_REPORT_ID_MCU_REQUEST 0x11

#define SUBCMD_REQUEST_DEVICE_INFO     0x02
#define SUBCMD_SET_INPUT_REPORT_MODE   0x03
#define SUBCMD_TRIGGER_BUTTONS_TIME    0x04
#define SUBCMD_SET_SHIPMENT_STATE      0x08
#define SUBCMD_SPI_FLASH_READ          0x10
#define SUBCMD_SET_NFC_IR_MCU_CONFIG   0x21
#define SUBCMD_SET_NFC_IR_MCU_STATE    0x22
#define SUBCMD_SET_PLAYER_LIGHTS       0x30
#define SUBCMD_ENABLE_6AXIS_SENSOR     0x40
#define SUBCMD_ENABLE_VIBRATION        0x48

#define ACK_STANDARD     0x80
#define ACK_DEVICE_INFO  0x82
#define ACK_TRIGGER_BTNS 0x83
#define ACK_SPI_READ     0x90
#define ACK_MCU_CONFIG   0xA0

#define INPUT_REPORT_SIZE_SUBCOMMAND 51
#define INPUT_REPORT_SIZE_IMU        50
#define INPUT_REPORT_SIZE_MCU        363
#define OUTPUT_REPORT_SIZE           50

#define MCU_DATA_OFFSET 50
#define MCU_DATA_SIZE   313

typedef enum {
    PROTO_STATE_DISCONNECTED,
    PROTO_STATE_PAIRING,
    PROTO_STATE_CONNECTED
} protocol_state_t;

typedef enum {
    MCU_STATE_SUSPENDED = 0x00,
    MCU_STATE_READY = 0x01,
    MCU_STATE_CONFIGURED_NFC = 0x04
} mcu_state_t;

typedef enum {
    NFC_STATE_NONE = 0x00,
    NFC_STATE_POLL = 0x01,
    NFC_STATE_PENDING_READ = 0x02,
    NFC_STATE_READING = 0x03,
    NFC_STATE_POLL_AGAIN = 0x09
} nfc_state_t;

typedef struct {
    protocol_state_t state;
    controller_state_t *controller;
    uint8_t mac_address[6];
    uint8_t input_report_mode;
    uint8_t timer;
    uint32_t timer_start_ms;
    bool player_lights_received;
    uint8_t player_number;
    mcu_state_t mcu_state;
    nfc_state_t nfc_state;
    uint8_t nfc_seq;
    uint8_t nfc_read_stage;
    const uint8_t *amiibo_data;
    uint16_t amiibo_size;
    uint8_t amiibo_uid[7];
    bool amiibo_loaded;
    uint8_t last_poll_uid[7];
    bool last_poll_uid_valid;
    uint8_t last_output_report_id;
    uint8_t last_mcu_cmd;
    uint8_t last_mcu_subcmd;
    uint16_t mcu_request_count;
    uint8_t last_mcu_response[24];
    uint8_t last_mcu_request[16];
} switch_protocol_t;

void switch_protocol_init(switch_protocol_t *proto, controller_state_t *controller, const uint8_t *mac);

void switch_protocol_set_connected(switch_protocol_t *proto, bool is_reconnect);
void switch_protocol_set_disconnected(switch_protocol_t *proto);

uint16_t switch_protocol_build_input_report(switch_protocol_t *proto, uint8_t *buffer, uint16_t max_size);
uint16_t switch_protocol_build_empty_report(switch_protocol_t *proto, uint8_t *buffer, uint16_t max_size);

bool switch_protocol_handle_output_report(switch_protocol_t *proto, const uint8_t *data, uint16_t len,
                                          uint8_t *response, uint16_t *response_len);

bool switch_protocol_is_ready_for_input(const switch_protocol_t *proto);
uint32_t switch_protocol_get_send_interval_ms(const switch_protocol_t *proto);
uint8_t switch_protocol_get_player_number(const switch_protocol_t *proto);

void switch_protocol_update_timer(switch_protocol_t *proto, uint32_t current_time_ms);

void switch_protocol_set_amiibo(switch_protocol_t *proto, const uint8_t *data, uint16_t size);
void switch_protocol_clear_amiibo(switch_protocol_t *proto);

#endif
