#include "host_protocol.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include "bt_hid.h"
#include "bonding_storage.h"
#include "cobs.h"
#include "crc8.h"

#define VERSION_MAJOR 1
#define VERSION_MINOR 0
#define VERSION_PATCH 0
#define VERSION_STRING "1.0.0"

static uint8_t s_decode_buffer[HOST_PROTO_RX_BUFFER_SIZE];
static uint8_t s_encode_buffer[HOST_PROTO_RX_BUFFER_SIZE];
static uint8_t s_packet_buffer[HOST_PROTO_MAX_PACKET];

static void send_response(host_protocol_t *proto, uint8_t cmd, host_status_t status,
                          const uint8_t *payload, size_t payload_len);
static void process_packet(host_protocol_t *proto, const uint8_t *data, size_t len);

void host_protocol_init(host_protocol_t *proto, controller_state_t *controller) {
    memset(proto, 0, sizeof(host_protocol_t));
    proto->controller = controller;
    proto->conn_state = HOST_CONN_DISCONNECTED;
    proto->player_number = 0xFF;
    proto->amiibo_state = HOST_AMIIBO_NONE;
    proto->log_level = HOST_LOG_NONE;
}

void host_protocol_set_callbacks(host_protocol_t *proto,
                                  host_start_advertising_fn start_adv,
                                  host_stop_advertising_fn stop_adv,
                                  host_disconnect_fn disconnect,
                                  host_set_led_fn set_led,
                                  host_reset_fn reset,
                                  host_send_fn send,
                                  host_press_button_fn press_button) {
    proto->start_advertising = start_adv;
    proto->stop_advertising = stop_adv;
    proto->disconnect = disconnect;
    proto->set_led = set_led;
    proto->reset = reset;
    proto->send = send;
    proto->press_button = press_button;
}

void host_protocol_set_amiibo_buffer(host_protocol_t *proto, uint8_t *buffer, uint16_t capacity) {
    proto->amiibo_data = buffer;
    proto->amiibo_data_capacity = capacity;
    proto->amiibo_upload_buffer = buffer;
}

void host_protocol_set_amiibo_callbacks(host_protocol_t *proto,
                                         host_amiibo_loaded_fn loaded,
                                         host_amiibo_cleared_fn cleared) {
    proto->amiibo_loaded = loaded;
    proto->amiibo_cleared = cleared;
}

void host_protocol_set_mcu_state_callback(host_protocol_t *proto, host_get_mcu_state_fn get_mcu_state) {
    proto->get_mcu_state = get_mcu_state;
}

void host_protocol_set_mcu_debug_callback(host_protocol_t *proto, host_get_mcu_debug_fn get_mcu_debug) {
    proto->get_mcu_debug = get_mcu_debug;
}

void host_protocol_rx_byte(host_protocol_t *proto, uint8_t byte) {
    if (byte == COBS_DELIMITER) {
        if (proto->rx_idx > 0) {
            size_t len = cobs_decode(proto->rx_buffer, proto->rx_idx, s_decode_buffer, sizeof(s_decode_buffer));
            if (len >= 4) {
                uint16_t pkt_len = s_decode_buffer[0] | (s_decode_buffer[1] << 8);
                if (pkt_len == len) {
                    uint8_t expected_crc = crc8(s_decode_buffer, len - 1);
                    if (expected_crc == s_decode_buffer[len - 1]) {
                        process_packet(proto, s_decode_buffer + 2, len - 3);
                    }
                }
            }
            proto->rx_idx = 0;
        }
    } else if (proto->rx_idx < HOST_PROTO_RX_BUFFER_SIZE) {
        proto->rx_buffer[proto->rx_idx++] = byte;
    }
}

void host_protocol_rx_bytes(host_protocol_t *proto, const uint8_t *data, size_t len) {
    for (size_t i = 0; i < len; i++) {
        host_protocol_rx_byte(proto, data[i]);
    }
}

void host_protocol_set_connection_state(host_protocol_t *proto, host_conn_state_t state, const uint8_t *addr) {
    proto->conn_state = state;
    if (addr != NULL) {
        memcpy(proto->switch_addr, addr, 6);
    } else {
        memset(proto->switch_addr, 0, 6);
    }
}

void host_protocol_set_player_number(host_protocol_t *proto, uint8_t player) {
    proto->player_number = player;
}

static void send_packet(host_protocol_t *proto, const uint8_t *packet, size_t len) {
    if (proto->send == NULL) {
        return;
    }

    size_t encoded_len = cobs_encode(packet, len, s_encode_buffer, sizeof(s_encode_buffer));
    s_encode_buffer[encoded_len++] = COBS_DELIMITER;
    proto->send(s_encode_buffer, encoded_len);
}

static void send_response(host_protocol_t *proto, uint8_t cmd, host_status_t status,
                          const uint8_t *payload, size_t payload_len) {
    if (payload_len > HOST_PROTO_MAX_PAYLOAD) {
        payload_len = HOST_PROTO_MAX_PAYLOAD;
    }

    uint16_t pkt_len = 2 + 1 + 1 + (uint16_t)payload_len + 1;

    s_packet_buffer[0] = pkt_len & 0xFF;
    s_packet_buffer[1] = (pkt_len >> 8) & 0xFF;
    s_packet_buffer[2] = cmd;
    s_packet_buffer[3] = status;

    if (payload != NULL && payload_len > 0) {
        memcpy(s_packet_buffer + 4, payload, payload_len);
    }

    s_packet_buffer[pkt_len - 1] = crc8(s_packet_buffer, pkt_len - 1);
    send_packet(proto, s_packet_buffer, pkt_len);
}

static void handle_get_status(host_protocol_t *proto) {
    uint8_t payload[10];
    payload[0] = proto->conn_state;
    payload[1] = proto->controller->type;
    payload[2] = proto->player_number;
    payload[3] = (proto->amiibo_state != HOST_AMIIBO_NONE) ? 1 : 0;
    memcpy(payload + 4, proto->switch_addr, 6);

    send_response(proto, HOST_CMD_GET_STATUS, HOST_STATUS_OK, payload, 10);
}

static void handle_start_advertising(host_protocol_t *proto) {
    host_protocol_log(proto, HOST_LOG_DEBUG, "HOST_CMD_START_ADVERTISING received");
    if (proto->start_advertising != NULL) {
        host_protocol_log(proto, HOST_LOG_DEBUG, "Calling start_advertising callback");
        proto->start_advertising();
        host_protocol_log(proto, HOST_LOG_DEBUG, "start_advertising callback completed");
    }
    host_protocol_log(proto, HOST_LOG_DEBUG, "Sending START_ADVERTISING response");
    send_response(proto, HOST_CMD_START_ADVERTISING, HOST_STATUS_OK, NULL, 0);
}

static void handle_stop_advertising(host_protocol_t *proto) {
    if (proto->stop_advertising != NULL) {
        proto->stop_advertising();
    }
    send_response(proto, HOST_CMD_STOP_ADVERTISING, HOST_STATUS_OK, NULL, 0);
}

static void handle_disconnect(host_protocol_t *proto) {
    if (proto->disconnect != NULL) {
        proto->disconnect();
    }
    send_response(proto, HOST_CMD_DISCONNECT, HOST_STATUS_OK, NULL, 0);
}

static void handle_set_controller_type(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    if (len < 1) {
        send_response(proto, HOST_CMD_SET_CONTROLLER_TYPE, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    uint8_t type = payload[0];
    if (type < CONTROLLER_JOYCON_L || type > CONTROLLER_PRO) {
        send_response(proto, HOST_CMD_SET_CONTROLLER_TYPE, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    controller_state_init(proto->controller, (controller_type_t)type);
    send_response(proto, HOST_CMD_SET_CONTROLLER_TYPE, HOST_STATUS_OK, NULL, 0);
}

static void handle_set_buttons(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    if (len < 6) {
        send_response(proto, HOST_CMD_SET_BUTTONS, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    for (int i = 0; i < 3; i++) {
        uint8_t buttons = payload[i];
        uint8_t mask = payload[i + 3];
        proto->controller->buttons[i] = (proto->controller->buttons[i] & ~mask) | (buttons & mask);
    }

    send_response(proto, HOST_CMD_SET_BUTTONS, HOST_STATUS_OK, NULL, 0);
}

static void handle_set_all_buttons(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    if (len < 3) {
        send_response(proto, HOST_CMD_SET_ALL_BUTTONS, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    memcpy(proto->controller->buttons, payload, 3);
    send_response(proto, HOST_CMD_SET_ALL_BUTTONS, HOST_STATUS_OK, NULL, 0);
}

static void handle_clear_buttons(host_protocol_t *proto) {
    controller_clear_buttons(proto->controller);
    send_response(proto, HOST_CMD_CLEAR_BUTTONS, HOST_STATUS_OK, NULL, 0);
}

static void handle_set_stick(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    if (len < 5) {
        send_response(proto, HOST_CMD_SET_STICK, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    bool is_left = (payload[0] == 0);
    uint16_t h = payload[1] | (payload[2] << 8);
    uint16_t v = payload[3] | (payload[4] << 8);

    controller_set_stick(proto->controller, is_left, h, v);
    send_response(proto, HOST_CMD_SET_STICK, HOST_STATUS_OK, NULL, 0);
}

static void handle_set_stick_preset(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    if (len < 2) {
        send_response(proto, HOST_CMD_SET_STICK_PRESET, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    bool is_left = (payload[0] == 0);
    uint8_t preset = payload[1];

    switch (preset) {
        case HOST_STICK_CENTER:
            controller_set_stick_center(proto->controller, is_left);
            break;
        case HOST_STICK_UP:
            controller_set_stick_up(proto->controller, is_left);
            break;
        case HOST_STICK_DOWN:
            controller_set_stick_down(proto->controller, is_left);
            break;
        case HOST_STICK_LEFT:
            controller_set_stick_left(proto->controller, is_left);
            break;
        case HOST_STICK_RIGHT:
            controller_set_stick_right(proto->controller, is_left);
            break;
        case HOST_STICK_UP_LEFT: {
            const stick_calibration_t *cal = is_left ? &proto->controller->left_cal : &proto->controller->right_cal;
            controller_set_stick(proto->controller, is_left,
                                  cal->h_center - cal->h_max_below,
                                  cal->v_center + cal->v_max_above);
            break;
        }
        case HOST_STICK_UP_RIGHT: {
            const stick_calibration_t *cal = is_left ? &proto->controller->left_cal : &proto->controller->right_cal;
            controller_set_stick(proto->controller, is_left,
                                  cal->h_center + cal->h_max_above,
                                  cal->v_center + cal->v_max_above);
            break;
        }
        case HOST_STICK_DOWN_LEFT: {
            const stick_calibration_t *cal = is_left ? &proto->controller->left_cal : &proto->controller->right_cal;
            controller_set_stick(proto->controller, is_left,
                                  cal->h_center - cal->h_max_below,
                                  cal->v_center - cal->v_max_below);
            break;
        }
        case HOST_STICK_DOWN_RIGHT: {
            const stick_calibration_t *cal = is_left ? &proto->controller->left_cal : &proto->controller->right_cal;
            controller_set_stick(proto->controller, is_left,
                                  cal->h_center + cal->h_max_above,
                                  cal->v_center - cal->v_max_below);
            break;
        }
        default:
            send_response(proto, HOST_CMD_SET_STICK_PRESET, HOST_STATUS_INVALID_PARAMS, NULL, 0);
            return;
    }

    send_response(proto, HOST_CMD_SET_STICK_PRESET, HOST_STATUS_OK, NULL, 0);
}

static void handle_get_input_state(host_protocol_t *proto) {
    uint8_t payload[11];
    memcpy(payload, proto->controller->buttons, 3);
    payload[3] = proto->controller->left_stick.h & 0xFF;
    payload[4] = (proto->controller->left_stick.h >> 8) & 0xFF;
    payload[5] = proto->controller->left_stick.v & 0xFF;
    payload[6] = (proto->controller->left_stick.v >> 8) & 0xFF;
    payload[7] = proto->controller->right_stick.h & 0xFF;
    payload[8] = (proto->controller->right_stick.h >> 8) & 0xFF;
    payload[9] = proto->controller->right_stick.v & 0xFF;
    payload[10] = (proto->controller->right_stick.v >> 8) & 0xFF;

    send_response(proto, HOST_CMD_GET_INPUT_STATE, HOST_STATUS_OK, payload, 11);
}

static void handle_amiibo_get_status(host_protocol_t *proto) {
    uint8_t payload[10];
    payload[0] = proto->amiibo_state;
    memcpy(payload + 1, proto->amiibo_uid, 7);
    payload[8] = proto->amiibo_size & 0xFF;
    payload[9] = (proto->amiibo_size >> 8) & 0xFF;

    send_response(proto, HOST_CMD_AMIIBO_GET_STATUS, HOST_STATUS_OK, payload, 10);
}

static void handle_amiibo_load(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    if (len < 2) {
        send_response(proto, HOST_CMD_AMIIBO_LOAD, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    if (proto->amiibo_data == NULL) {
        send_response(proto, HOST_CMD_AMIIBO_LOAD, HOST_STATUS_ERROR, NULL, 0);
        return;
    }

    uint16_t size = payload[0] | (payload[1] << 8);
    if (size > proto->amiibo_data_capacity || len < 2 + size) {
        send_response(proto, HOST_CMD_AMIIBO_LOAD, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    memcpy(proto->amiibo_data, payload + 2, size);
    proto->amiibo_size = size;
    if (size >= 8) {
        proto->amiibo_uid[0] = proto->amiibo_data[0];
        proto->amiibo_uid[1] = proto->amiibo_data[1];
        proto->amiibo_uid[2] = proto->amiibo_data[2];
        proto->amiibo_uid[3] = proto->amiibo_data[4];
        proto->amiibo_uid[4] = proto->amiibo_data[5];
        proto->amiibo_uid[5] = proto->amiibo_data[6];
        proto->amiibo_uid[6] = proto->amiibo_data[7];
    } else {
        memset(proto->amiibo_uid, 0, 7);
    }
    proto->amiibo_state = HOST_AMIIBO_LOADED;
    if (proto->amiibo_loaded) {
        proto->amiibo_loaded(proto->amiibo_data, proto->amiibo_size);
    }

    send_response(proto, HOST_CMD_AMIIBO_LOAD, HOST_STATUS_OK, NULL, 0);
}

static void handle_amiibo_load_start(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    if (len < 2) {
        send_response(proto, HOST_CMD_AMIIBO_LOAD_START, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    if (proto->amiibo_upload_buffer == NULL) {
        send_response(proto, HOST_CMD_AMIIBO_LOAD_START, HOST_STATUS_ERROR, NULL, 0);
        return;
    }

    uint16_t size = payload[0] | (payload[1] << 8);
    if (size > proto->amiibo_data_capacity) {
        send_response(proto, HOST_CMD_AMIIBO_LOAD_START, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    proto->amiibo_upload_size = size;
    proto->amiibo_upload_received = 0;

    uint8_t response_payload[1] = { HOST_PROTO_AMIIBO_CHUNK_SIZE };
    send_response(proto, HOST_CMD_AMIIBO_LOAD_START, HOST_STATUS_OK, response_payload, 1);
}

static void handle_amiibo_load_chunk(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    if (len < 1) {
        send_response(proto, HOST_CMD_AMIIBO_LOAD_CHUNK, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    if (proto->amiibo_upload_buffer == NULL) {
        send_response(proto, HOST_CMD_AMIIBO_LOAD_CHUNK, HOST_STATUS_ERROR, NULL, 0);
        return;
    }

    uint8_t chunk_idx = payload[0];
    size_t chunk_data_len = len - 1;
    uint16_t expected_offset = chunk_idx * HOST_PROTO_AMIIBO_CHUNK_SIZE;

    if (expected_offset != proto->amiibo_upload_received) {
        send_response(proto, HOST_CMD_AMIIBO_LOAD_CHUNK, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    if (proto->amiibo_upload_received + chunk_data_len > proto->amiibo_upload_size) {
        chunk_data_len = proto->amiibo_upload_size - proto->amiibo_upload_received;
    }

    memcpy(proto->amiibo_upload_buffer + proto->amiibo_upload_received, payload + 1, chunk_data_len);
    proto->amiibo_upload_received += chunk_data_len;

    send_response(proto, HOST_CMD_AMIIBO_LOAD_CHUNK, HOST_STATUS_OK, NULL, 0);
}

static void handle_amiibo_load_finish(host_protocol_t *proto) {
    if (proto->amiibo_upload_received != proto->amiibo_upload_size) {
        send_response(proto, HOST_CMD_AMIIBO_LOAD_FINISH, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    proto->amiibo_size = proto->amiibo_upload_size;
    if (proto->amiibo_size >= 8) {
        proto->amiibo_uid[0] = proto->amiibo_data[0];
        proto->amiibo_uid[1] = proto->amiibo_data[1];
        proto->amiibo_uid[2] = proto->amiibo_data[2];
        proto->amiibo_uid[3] = proto->amiibo_data[4];
        proto->amiibo_uid[4] = proto->amiibo_data[5];
        proto->amiibo_uid[5] = proto->amiibo_data[6];
        proto->amiibo_uid[6] = proto->amiibo_data[7];
    } else {
        memset(proto->amiibo_uid, 0, 7);
    }
    proto->amiibo_state = HOST_AMIIBO_LOADED;
    if (proto->amiibo_loaded) {
        proto->amiibo_loaded(proto->amiibo_data, proto->amiibo_size);
    }

    send_response(proto, HOST_CMD_AMIIBO_LOAD_FINISH, HOST_STATUS_OK, proto->amiibo_uid, 7);
}

static void handle_amiibo_clear(host_protocol_t *proto) {
    proto->amiibo_state = HOST_AMIIBO_NONE;
    proto->amiibo_size = 0;
    memset(proto->amiibo_uid, 0, 7);
    if (proto->amiibo_cleared) {
        proto->amiibo_cleared();
    }

    send_response(proto, HOST_CMD_AMIIBO_CLEAR, HOST_STATUS_OK, NULL, 0);
}

static void handle_amiibo_set_readonly(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    if (len < 1) {
        send_response(proto, HOST_CMD_AMIIBO_SET_READONLY, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    proto->amiibo_readonly = (payload[0] != 0);
    send_response(proto, HOST_CMD_AMIIBO_SET_READONLY, HOST_STATUS_OK, NULL, 0);
}

static void handle_get_mcu_state(host_protocol_t *proto) {
    uint8_t payload[10] = {0};
    uint16_t mcu_req_count = 0;
    if (proto->get_mcu_state != NULL) {
        proto->get_mcu_state(&payload[0], &payload[1], &payload[2], &payload[3],
                             &payload[4], &payload[5], &payload[6], &mcu_req_count);
        payload[7] = mcu_req_count & 0xFF;
        payload[8] = (mcu_req_count >> 8) & 0xFF;
    }
    send_response(proto, HOST_CMD_GET_MCU_STATE, HOST_STATUS_OK, payload, 9);
}

static void handle_get_mcu_debug(host_protocol_t *proto) {
    uint8_t payload[40] = {0};
    if (proto->get_mcu_debug != NULL) {
        proto->get_mcu_debug(payload, payload + 16);
    }
    send_response(proto, HOST_CMD_GET_MCU_DEBUG, HOST_STATUS_OK, payload, 40);
}

static void handle_reconnect(host_protocol_t *proto) {
    host_protocol_log(proto, HOST_LOG_DEBUG, "HOST_CMD_RECONNECT received");
    bd_addr_t addr;
    if (!bt_hid_get_bonding_status(&addr)) {
        host_protocol_log(proto, HOST_LOG_INFO, "No bonding found, returning error");
        send_response(proto, HOST_CMD_RECONNECT, HOST_STATUS_ERROR, NULL, 0);
        return;
    }

    reconnect_policy_t policy = {
        .type = RECONNECT_POLICY_USER,
        .max_attempts = 5,
        .base_interval_ms = 3000,
        .use_exponential_backoff = false
    };

    if (bt_hid_reconnect(addr, policy)) {
        host_protocol_log(proto, HOST_LOG_INFO, "Reconnect initiated, returning OK");
        send_response(proto, HOST_CMD_RECONNECT, HOST_STATUS_OK, NULL, 0);
    } else {
        host_protocol_log(proto, HOST_LOG_INFO, "Reconnect busy, returning BUSY");
        send_response(proto, HOST_CMD_RECONNECT, HOST_STATUS_BUSY, NULL, 0);
    }
}

static void handle_forget_bonding(host_protocol_t *proto) {
    host_protocol_log(proto, HOST_LOG_DEBUG, "HOST_CMD_FORGET_BONDING received");
    bt_hid_clear_bonding();
    host_protocol_log(proto, HOST_LOG_INFO, "Bonding cleared, sending response");
    send_response(proto, HOST_CMD_FORGET_BONDING, HOST_STATUS_OK, NULL, 0);
}

static void handle_get_bonding_status(host_protocol_t *proto) {
    host_protocol_log(proto, HOST_LOG_DEBUG, "HOST_CMD_GET_BONDING_STATUS received");
    bd_addr_t addr;
    bool bonded = bt_hid_get_bonding_status(&addr);

    uint8_t payload[13];
    payload[0] = bonded ? 1 : 0;
    if (bonded) {
        memcpy(payload + 1, addr, 6);
    } else {
        memset(payload + 1, 0, 6);
    }

    uint32_t timestamp = 0;
    uint16_t count = 0;
    if (bonded) {
        bonding_storage_get_stats(&timestamp, &count);
    }

    payload[7] = (timestamp >> 24) & 0xFF;
    payload[8] = (timestamp >> 16) & 0xFF;
    payload[9] = (timestamp >> 8) & 0xFF;
    payload[10] = timestamp & 0xFF;
    payload[11] = (count >> 8) & 0xFF;
    payload[12] = count & 0xFF;

    host_protocol_logf(proto, HOST_LOG_DEBUG, "Bonded: %d, timestamp: %lu, count: %d, sending response", bonded, timestamp, count);
    send_response(proto, HOST_CMD_GET_BONDING_STATUS, HOST_STATUS_OK, payload, 13);
}

static void handle_ping(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    send_response(proto, HOST_CMD_PING, HOST_STATUS_OK, payload, len);
}

static void handle_get_version(host_protocol_t *proto) {
    uint8_t payload[3 + sizeof(VERSION_STRING)];
    payload[0] = VERSION_MAJOR;
    payload[1] = VERSION_MINOR;
    payload[2] = VERSION_PATCH;
    memcpy(payload + 3, VERSION_STRING, sizeof(VERSION_STRING));

    send_response(proto, HOST_CMD_GET_VERSION, HOST_STATUS_OK, payload, 3 + sizeof(VERSION_STRING));
}

static void handle_reset(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    bool bootloader = (len >= 1 && payload[0] == 0x01);
    if (proto->reset != NULL) {
        proto->reset(bootloader);
    }
}

static void handle_set_led(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    if (len < 1) {
        send_response(proto, HOST_CMD_SET_LED, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    if (payload[0] > HOST_LED_AUTO) {
        send_response(proto, HOST_CMD_SET_LED, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    if (proto->set_led != NULL) {
        proto->set_led((host_led_mode_t)payload[0]);
    }
    send_response(proto, HOST_CMD_SET_LED, HOST_STATUS_OK, NULL, 0);
}

static void handle_set_log_level(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    if (len < 1) {
        send_response(proto, HOST_CMD_SET_LOG_LEVEL, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    if (payload[0] > HOST_LOG_DEBUG) {
        send_response(proto, HOST_CMD_SET_LOG_LEVEL, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    proto->log_level = (host_log_level_t)payload[0];
    send_response(proto, HOST_CMD_SET_LOG_LEVEL, HOST_STATUS_OK, NULL, 0);
}

static void handle_press_button(host_protocol_t *proto, const uint8_t *payload, size_t len) {
    if (len < 3) {
        send_response(proto, HOST_CMD_PRESS_BUTTON, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    uint8_t button_id = payload[0];
    uint16_t duration_ms = payload[1] | (payload[2] << 8);

    if (button_id > 0x11) {
        send_response(proto, HOST_CMD_PRESS_BUTTON, HOST_STATUS_INVALID_PARAMS, NULL, 0);
        return;
    }

    if (proto->press_button != NULL) {
        proto->press_button(button_id, duration_ms);
    }
    send_response(proto, HOST_CMD_PRESS_BUTTON, HOST_STATUS_OK, NULL, 0);
}

static void process_packet(host_protocol_t *proto, const uint8_t *data, size_t len) {
    if (len < 1) {
        return;
    }

    uint8_t cmd = data[0];
    const uint8_t *payload = (len > 1) ? data + 1 : NULL;
    size_t payload_len = (len > 1) ? len - 1 : 0;

    switch (cmd) {
        case HOST_CMD_GET_STATUS:
            handle_get_status(proto);
            break;
        case HOST_CMD_START_ADVERTISING:
            handle_start_advertising(proto);
            break;
        case HOST_CMD_STOP_ADVERTISING:
            handle_stop_advertising(proto);
            break;
        case HOST_CMD_DISCONNECT:
            handle_disconnect(proto);
            break;
        case HOST_CMD_SET_CONTROLLER_TYPE:
            handle_set_controller_type(proto, payload, payload_len);
            break;
        case HOST_CMD_SET_BUTTONS:
            handle_set_buttons(proto, payload, payload_len);
            break;
        case HOST_CMD_SET_ALL_BUTTONS:
            handle_set_all_buttons(proto, payload, payload_len);
            break;
        case HOST_CMD_CLEAR_BUTTONS:
            handle_clear_buttons(proto);
            break;
        case HOST_CMD_SET_STICK:
            handle_set_stick(proto, payload, payload_len);
            break;
        case HOST_CMD_SET_STICK_PRESET:
            handle_set_stick_preset(proto, payload, payload_len);
            break;
        case HOST_CMD_GET_INPUT_STATE:
            handle_get_input_state(proto);
            break;
        case HOST_CMD_PRESS_BUTTON:
            handle_press_button(proto, payload, payload_len);
            break;
        case HOST_CMD_AMIIBO_GET_STATUS:
            handle_amiibo_get_status(proto);
            break;
        case HOST_CMD_AMIIBO_LOAD:
            handle_amiibo_load(proto, payload, payload_len);
            break;
        case HOST_CMD_AMIIBO_LOAD_START:
            handle_amiibo_load_start(proto, payload, payload_len);
            break;
        case HOST_CMD_AMIIBO_LOAD_CHUNK:
            handle_amiibo_load_chunk(proto, payload, payload_len);
            break;
        case HOST_CMD_AMIIBO_LOAD_FINISH:
            handle_amiibo_load_finish(proto);
            break;
        case HOST_CMD_AMIIBO_CLEAR:
            handle_amiibo_clear(proto);
            break;
        case HOST_CMD_AMIIBO_SET_READONLY:
            handle_amiibo_set_readonly(proto, payload, payload_len);
            break;
        case HOST_CMD_GET_MCU_STATE:
            handle_get_mcu_state(proto);
            break;
        case HOST_CMD_GET_MCU_DEBUG:
            handle_get_mcu_debug(proto);
            break;
        case HOST_CMD_RECONNECT:
            handle_reconnect(proto);
            break;
        case HOST_CMD_FORGET_BONDING:
            handle_forget_bonding(proto);
            break;
        case HOST_CMD_GET_BONDING_STATUS:
            handle_get_bonding_status(proto);
            break;
        case HOST_CMD_PING:
            handle_ping(proto, payload, payload_len);
            break;
        case HOST_CMD_GET_VERSION:
            handle_get_version(proto);
            break;
        case HOST_CMD_RESET:
            handle_reset(proto, payload, payload_len);
            break;
        case HOST_CMD_SET_LED:
            handle_set_led(proto, payload, payload_len);
            break;
        case HOST_CMD_SET_LOG_LEVEL:
            handle_set_log_level(proto, payload, payload_len);
            break;
        default:
            send_response(proto, cmd, HOST_STATUS_UNKNOWN_CMD, NULL, 0);
            break;
    }
}

void host_protocol_send_event_connection(host_protocol_t *proto, host_conn_state_t state, const uint8_t *addr) {
    uint16_t pkt_len = 2 + 1 + 7 + 1;

    s_packet_buffer[0] = pkt_len & 0xFF;
    s_packet_buffer[1] = (pkt_len >> 8) & 0xFF;
    s_packet_buffer[2] = HOST_EVT_CONNECTION_CHANGED;
    s_packet_buffer[3] = state;
    if (addr != NULL) {
        memcpy(s_packet_buffer + 4, addr, 6);
    } else {
        memset(s_packet_buffer + 4, 0, 6);
    }
    s_packet_buffer[pkt_len - 1] = crc8(s_packet_buffer, pkt_len - 1);

    send_packet(proto, s_packet_buffer, pkt_len);
}

void host_protocol_send_event_amiibo_scanned(host_protocol_t *proto, bool write_request) {
    uint16_t pkt_len = 2 + 1 + 1 + 1;

    s_packet_buffer[0] = pkt_len & 0xFF;
    s_packet_buffer[1] = (pkt_len >> 8) & 0xFF;
    s_packet_buffer[2] = HOST_EVT_AMIIBO_SCANNED;
    s_packet_buffer[3] = write_request ? 0x01 : 0x00;
    s_packet_buffer[pkt_len - 1] = crc8(s_packet_buffer, pkt_len - 1);

    send_packet(proto, s_packet_buffer, pkt_len);
}

void host_protocol_send_event_amiibo_write_complete(host_protocol_t *proto, bool success) {
    uint16_t pkt_len = 2 + 1 + 1 + 1;

    s_packet_buffer[0] = pkt_len & 0xFF;
    s_packet_buffer[1] = (pkt_len >> 8) & 0xFF;
    s_packet_buffer[2] = HOST_EVT_AMIIBO_WRITE_COMPLETE;
    s_packet_buffer[3] = success ? 0x00 : 0x01;
    s_packet_buffer[pkt_len - 1] = crc8(s_packet_buffer, pkt_len - 1);

    send_packet(proto, s_packet_buffer, pkt_len);
}

void host_protocol_send_event_error(host_protocol_t *proto, uint8_t code, const char *msg) {
    size_t msg_len = (msg != NULL) ? strlen(msg) + 1 : 0;
    if (msg_len > HOST_PROTO_MAX_PAYLOAD - 1) {
        msg_len = HOST_PROTO_MAX_PAYLOAD - 1;
    }
    uint16_t pkt_len = 2 + 1 + 1 + (uint16_t)msg_len + 1;

    s_packet_buffer[0] = pkt_len & 0xFF;
    s_packet_buffer[1] = (pkt_len >> 8) & 0xFF;
    s_packet_buffer[2] = HOST_EVT_ERROR;
    s_packet_buffer[3] = code;
    if (msg != NULL && msg_len > 0) {
        memcpy(s_packet_buffer + 4, msg, msg_len);
    }
    s_packet_buffer[pkt_len - 1] = crc8(s_packet_buffer, pkt_len - 1);

    send_packet(proto, s_packet_buffer, pkt_len);
}

void host_protocol_log(host_protocol_t *proto, host_log_level_t level, const char *msg) {
    if (proto->log_level == HOST_LOG_NONE || level > proto->log_level) {
        return;
    }

    size_t msg_len = (msg != NULL) ? strlen(msg) + 1 : 0;
    if (msg_len > HOST_PROTO_MAX_PAYLOAD - 1) {
        msg_len = HOST_PROTO_MAX_PAYLOAD - 1;
    }
    uint16_t pkt_len = 2 + 1 + 1 + (uint16_t)msg_len + 1;

    s_packet_buffer[0] = pkt_len & 0xFF;
    s_packet_buffer[1] = (pkt_len >> 8) & 0xFF;
    s_packet_buffer[2] = HOST_EVT_LOG;
    s_packet_buffer[3] = level;
    if (msg != NULL && msg_len > 0) {
        memcpy(s_packet_buffer + 4, msg, msg_len);
    }
    s_packet_buffer[pkt_len - 1] = crc8(s_packet_buffer, pkt_len - 1);

    send_packet(proto, s_packet_buffer, pkt_len);
}

void host_protocol_logf(host_protocol_t *proto, host_log_level_t level, const char *fmt, ...) {
    if (proto->log_level == HOST_LOG_NONE || level > proto->log_level) {
        return;
    }

    static char log_buffer[HOST_PROTO_MAX_PAYLOAD];

    va_list args;
    va_start(args, fmt);
    vsnprintf(log_buffer, sizeof(log_buffer), fmt, args);
    va_end(args);

    host_protocol_log(proto, level, log_buffer);
}

size_t host_protocol_build_packet(uint8_t cmd, const uint8_t *payload, size_t payload_len,
                                   uint8_t *output, size_t output_size) {
    uint16_t pkt_len = 2 + 1 + payload_len + 1;
    if (output_size < pkt_len) {
        return 0;
    }

    output[0] = pkt_len & 0xFF;
    output[1] = (pkt_len >> 8) & 0xFF;
    output[2] = cmd;
    if (payload != NULL && payload_len > 0) {
        memcpy(output + 3, payload, payload_len);
    }
    output[pkt_len - 1] = crc8(output, pkt_len - 1);

    return pkt_len;
}

size_t host_protocol_build_response(uint8_t cmd, host_status_t status,
                                     const uint8_t *payload, size_t payload_len,
                                     uint8_t *output, size_t output_size) {
    uint16_t pkt_len = 2 + 1 + 1 + payload_len + 1;
    if (output_size < pkt_len) {
        return 0;
    }

    output[0] = pkt_len & 0xFF;
    output[1] = (pkt_len >> 8) & 0xFF;
    output[2] = cmd;
    output[3] = status;
    if (payload != NULL && payload_len > 0) {
        memcpy(output + 4, payload, payload_len);
    }
    output[pkt_len - 1] = crc8(output, pkt_len - 1);

    return pkt_len;
}

bool host_protocol_parse_packet(const uint8_t *data, size_t len,
                                 uint8_t *cmd, uint8_t **payload, size_t *payload_len) {
    if (len < 4) {
        return false;
    }

    uint16_t pkt_len = data[0] | (data[1] << 8);
    if (pkt_len != len) {
        return false;
    }

    uint8_t expected_crc = crc8(data, len - 1);
    if (expected_crc != data[len - 1]) {
        return false;
    }

    *cmd = data[2];
    *payload_len = len - 4;
    *payload = (*payload_len > 0) ? (uint8_t *)(data + 3) : NULL;

    return true;
}

bool host_protocol_parse_response(const uint8_t *data, size_t len,
                                   uint8_t *cmd, host_status_t *status,
                                   uint8_t **payload, size_t *payload_len) {
    if (len < 5) {
        return false;
    }

    uint16_t pkt_len = data[0] | (data[1] << 8);
    if (pkt_len != len) {
        return false;
    }

    uint8_t expected_crc = crc8(data, len - 1);
    if (expected_crc != data[len - 1]) {
        return false;
    }

    *cmd = data[2];
    *status = (host_status_t)data[3];
    *payload_len = len - 5;
    *payload = (*payload_len > 0) ? (uint8_t *)(data + 4) : NULL;

    return true;
}
