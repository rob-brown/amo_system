#ifndef HOST_PROTOCOL_H
#define HOST_PROTOCOL_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "controller_state.h"

#define HOST_PROTO_MAX_PAYLOAD 2100
#define HOST_PROTO_HEADER_SIZE 3
#define HOST_PROTO_CHECKSUM_SIZE 1
#define HOST_PROTO_MAX_PACKET (HOST_PROTO_HEADER_SIZE + HOST_PROTO_MAX_PAYLOAD + HOST_PROTO_CHECKSUM_SIZE)
#define HOST_PROTO_RX_BUFFER_SIZE 2200
#define HOST_PROTO_AMIIBO_CHUNK_SIZE 128

typedef enum {
    HOST_CMD_GET_STATUS = 0x01,
    HOST_CMD_START_ADVERTISING = 0x02,
    HOST_CMD_STOP_ADVERTISING = 0x03,
    HOST_CMD_DISCONNECT = 0x04,
    HOST_CMD_SET_CONTROLLER_TYPE = 0x05,
    HOST_CMD_SET_BUTTONS = 0x10,
    HOST_CMD_SET_ALL_BUTTONS = 0x11,
    HOST_CMD_CLEAR_BUTTONS = 0x12,
    HOST_CMD_SET_STICK = 0x13,
    HOST_CMD_SET_STICK_PRESET = 0x14,
    HOST_CMD_GET_INPUT_STATE = 0x15,
    HOST_CMD_PRESS_BUTTON = 0x20,
    HOST_CMD_INPUT_SEQUENCE = 0x21,
    HOST_CMD_AMIIBO_GET_STATUS = 0x30,
    HOST_CMD_AMIIBO_LOAD = 0x31,
    HOST_CMD_AMIIBO_LOAD_START = 0x32,
    HOST_CMD_AMIIBO_LOAD_CHUNK = 0x33,
    HOST_CMD_AMIIBO_LOAD_FINISH = 0x34,
    HOST_CMD_AMIIBO_READ = 0x35,
    HOST_CMD_AMIIBO_READ_CHUNK = 0x36,
    HOST_CMD_AMIIBO_CLEAR = 0x37,
    HOST_CMD_AMIIBO_SET_READONLY = 0x38,
    HOST_CMD_GET_MCU_STATE = 0x39,
    HOST_CMD_GET_MCU_DEBUG = 0x3A,
    HOST_CMD_RECONNECT = 0x40,
    HOST_CMD_FORGET_BONDING = 0x41,
    HOST_CMD_GET_BONDING_STATUS = 0x42,
    HOST_CMD_PING = 0xF0,
    HOST_CMD_GET_VERSION = 0xF1,
    HOST_CMD_RESET = 0xF2,
    HOST_CMD_SET_LED = 0xF3,
    HOST_CMD_SET_LOG_LEVEL = 0xF4,
    HOST_EVT_CONNECTION_CHANGED = 0xE0,
    HOST_EVT_AMIIBO_SCANNED = 0xE1,
    HOST_EVT_AMIIBO_WRITE_COMPLETE = 0xE2,
    HOST_EVT_ERROR = 0xE3,
    HOST_EVT_RECONNECT_SUCCESS = 0xE4,
    HOST_EVT_RECONNECT_FAILED = 0xE5,
    HOST_EVT_BONDING_CLEARED = 0xE6,
    HOST_EVT_LOG = 0xE7
} host_cmd_t;

typedef enum {
    HOST_STATUS_OK = 0x00,
    HOST_STATUS_UNKNOWN_CMD = 0x01,
    HOST_STATUS_INVALID_PARAMS = 0x02,
    HOST_STATUS_BUSY = 0x03,
    HOST_STATUS_NOT_CONNECTED = 0x04,
    HOST_STATUS_AMIIBO_ERROR = 0x05,
    HOST_STATUS_ERROR = 0xFF
} host_status_t;

typedef enum {
    HOST_CONN_DISCONNECTED = 0x00,
    HOST_CONN_ADVERTISING = 0x01,
    HOST_CONN_PAIRING = 0x02,
    HOST_CONN_READY = 0x03
} host_conn_state_t;

typedef enum {
    HOST_AMIIBO_NONE = 0x00,
    HOST_AMIIBO_LOADED = 0x01,
    HOST_AMIIBO_READING = 0x02,
    HOST_AMIIBO_WRITING = 0x03
} host_amiibo_state_t;

typedef enum {
    HOST_STICK_CENTER = 0x00,
    HOST_STICK_UP = 0x01,
    HOST_STICK_DOWN = 0x02,
    HOST_STICK_LEFT = 0x03,
    HOST_STICK_RIGHT = 0x04,
    HOST_STICK_UP_LEFT = 0x05,
    HOST_STICK_UP_RIGHT = 0x06,
    HOST_STICK_DOWN_LEFT = 0x07,
    HOST_STICK_DOWN_RIGHT = 0x08
} host_stick_preset_t;

typedef enum {
    HOST_LED_OFF = 0x00,
    HOST_LED_ON = 0x01,
    HOST_LED_BLINK_SLOW = 0x02,
    HOST_LED_BLINK_FAST = 0x03,
    HOST_LED_AUTO = 0x04
} host_led_mode_t;

// See RFC5424 https://datatracker.ietf.org/doc/html/rfc5424
typedef enum {
    HOST_LOG_NONE = 0x00,
    HOST_LOG_EMERGENCY = 0x01,
    HOST_LOG_ALERT = 0x02,
    HOST_LOG_CRITICAL = 0x03,
    HOST_LOG_ERROR = 0x04,
    HOST_LOG_WARNING = 0x05,
    HOST_LOG_NOTICE = 0x06,
    HOST_LOG_INFO = 0x07,
    HOST_LOG_DEBUG = 0x08
} host_log_level_t;

typedef void (*host_start_advertising_fn)(void);
typedef void (*host_stop_advertising_fn)(void);
typedef void (*host_disconnect_fn)(void);
typedef void (*host_set_led_fn)(host_led_mode_t mode);
typedef void (*host_reset_fn)(bool bootloader);
typedef void (*host_send_fn)(const uint8_t *data, size_t len);
typedef void (*host_press_button_fn)(uint8_t button_id, uint16_t duration_ms);
typedef void (*host_amiibo_loaded_fn)(const uint8_t *data, uint16_t size);
typedef void (*host_amiibo_cleared_fn)(void);
typedef void (*host_get_mcu_state_fn)(uint8_t *mcu_state, uint8_t *nfc_state, uint8_t *input_mode, uint8_t *amiibo_loaded,
                                      uint8_t *last_report_id, uint8_t *last_mcu_cmd, uint8_t *last_mcu_subcmd, uint16_t *mcu_req_count);
typedef void (*host_get_mcu_debug_fn)(uint8_t *last_request, uint8_t *last_response);

typedef struct {
    controller_state_t *controller;
    host_conn_state_t conn_state;
    uint8_t switch_addr[6];
    uint8_t player_number;
    host_amiibo_state_t amiibo_state;
    uint8_t amiibo_uid[7];
    uint16_t amiibo_size;
    uint8_t *amiibo_data;
    uint16_t amiibo_data_capacity;
    uint8_t *amiibo_upload_buffer;
    uint16_t amiibo_upload_size;
    uint16_t amiibo_upload_received;
    bool amiibo_readonly;
    uint8_t rx_buffer[HOST_PROTO_RX_BUFFER_SIZE];
    size_t rx_idx;
    host_log_level_t log_level;
    host_start_advertising_fn start_advertising;
    host_stop_advertising_fn stop_advertising;
    host_disconnect_fn disconnect;
    host_set_led_fn set_led;
    host_reset_fn reset;
    host_send_fn send;
    host_press_button_fn press_button;
    host_amiibo_loaded_fn amiibo_loaded;
    host_amiibo_cleared_fn amiibo_cleared;
    host_get_mcu_state_fn get_mcu_state;
    host_get_mcu_debug_fn get_mcu_debug;
} host_protocol_t;

void host_protocol_init(host_protocol_t *proto, controller_state_t *controller);
void host_protocol_set_callbacks(host_protocol_t *proto,
                                  host_start_advertising_fn start_adv,
                                  host_stop_advertising_fn stop_adv,
                                  host_disconnect_fn disconnect,
                                  host_set_led_fn set_led,
                                  host_reset_fn reset,
                                  host_send_fn send,
                                  host_press_button_fn press_button);
void host_protocol_set_amiibo_buffer(host_protocol_t *proto, uint8_t *buffer, uint16_t capacity);
void host_protocol_set_amiibo_callbacks(host_protocol_t *proto,
                                         host_amiibo_loaded_fn loaded,
                                         host_amiibo_cleared_fn cleared);
void host_protocol_set_mcu_state_callback(host_protocol_t *proto, host_get_mcu_state_fn get_mcu_state);
void host_protocol_set_mcu_debug_callback(host_protocol_t *proto, host_get_mcu_debug_fn get_mcu_debug);

void host_protocol_rx_byte(host_protocol_t *proto, uint8_t byte);
void host_protocol_rx_bytes(host_protocol_t *proto, const uint8_t *data, size_t len);

void host_protocol_set_connection_state(host_protocol_t *proto, host_conn_state_t state, const uint8_t *addr);
void host_protocol_set_player_number(host_protocol_t *proto, uint8_t player);

void host_protocol_send_event_connection(host_protocol_t *proto, host_conn_state_t state, const uint8_t *addr);
void host_protocol_send_event_amiibo_scanned(host_protocol_t *proto, bool write_request);
void host_protocol_send_event_amiibo_write_complete(host_protocol_t *proto, bool success);
void host_protocol_send_event_error(host_protocol_t *proto, uint8_t code, const char *msg);

void host_protocol_log(host_protocol_t *proto, host_log_level_t level, const char *msg);
void host_protocol_logf(host_protocol_t *proto, host_log_level_t level, const char *fmt, ...);

size_t host_protocol_build_packet(uint8_t cmd, const uint8_t *payload, size_t payload_len,
                                   uint8_t *output, size_t output_size);
size_t host_protocol_build_response(uint8_t cmd, host_status_t status,
                                     const uint8_t *payload, size_t payload_len,
                                     uint8_t *output, size_t output_size);

bool host_protocol_parse_packet(const uint8_t *data, size_t len,
                                 uint8_t *cmd, uint8_t **payload, size_t *payload_len);
bool host_protocol_parse_response(const uint8_t *data, size_t len,
                                   uint8_t *cmd, host_status_t *status,
                                   uint8_t **payload, size_t *payload_len);

#endif
