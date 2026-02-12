#include "switch_protocol.h"
#include "spi_flash_data.h"
#include "crc8.h"
#include "logging.h"
#include <string.h>

#define MISC_BYTE 0x8E
#define VIBRATOR_INPUT 0x80

#define NFC_CMD_START_POLL  0x01
#define NFC_CMD_STOP_POLL   0x02
#define NFC_CMD_STATUS      0x04
#define NFC_CMD_READ_WRITE  0x06

static void build_report_header(switch_protocol_t *proto, uint8_t *buffer, uint8_t report_id) {
    buffer[0] = HID_REPORT_INPUT;
    buffer[1] = report_id;
    buffer[2] = proto->timer;
    buffer[3] = MISC_BYTE;

    memcpy(&buffer[4], proto->controller->buttons, 3);

    uint8_t stick_data[3];
    controller_encode_stick(&proto->controller->left_stick, stick_data);
    memcpy(&buffer[7], stick_data, 3);

    controller_encode_stick(&proto->controller->right_stick, stick_data);
    memcpy(&buffer[10], stick_data, 3);

    buffer[13] = VIBRATOR_INPUT;
}

static uint16_t handle_request_device_info(switch_protocol_t *proto, uint8_t *response) {
    response[14] = ACK_DEVICE_INFO;
    response[15] = SUBCMD_REQUEST_DEVICE_INFO;

    response[16] = 0x04;
    response[17] = 0x00;

    response[18] = proto->controller->type;

    response[19] = 0x02;

    for (int i = 0; i < 6; i++) {
        response[20 + i] = proto->mac_address[i];
    }

    response[26] = 0x01;
    response[27] = 0x01;

    return INPUT_REPORT_SIZE_SUBCOMMAND;
}

static uint16_t handle_set_input_report_mode(switch_protocol_t *proto, const uint8_t *data, uint8_t *response) {
    uint8_t old_mode = proto->input_report_mode;
    proto->input_report_mode = data[0];

    pico_log_noticef("Input report mode changed: 0x%02X -> 0x%02X", old_mode, proto->input_report_mode);

    response[14] = ACK_STANDARD;
    response[15] = SUBCMD_SET_INPUT_REPORT_MODE;

    return INPUT_REPORT_SIZE_SUBCOMMAND;
}

static uint16_t handle_trigger_buttons_time(switch_protocol_t *proto, uint8_t *response) {
    response[14] = ACK_TRIGGER_BTNS;
    response[15] = SUBCMD_TRIGGER_BUTTONS_TIME;

    uint16_t time_value = 300;

    if (proto->controller->type == CONTROLLER_PRO) {
        response[16] = time_value & 0xFF;
        response[17] = (time_value >> 8) & 0xFF;
        response[18] = time_value & 0xFF;
        response[19] = (time_value >> 8) & 0xFF;
    } else {
        response[24] = time_value & 0xFF;
        response[25] = (time_value >> 8) & 0xFF;
        response[26] = time_value & 0xFF;
        response[27] = (time_value >> 8) & 0xFF;
    }

    return INPUT_REPORT_SIZE_SUBCOMMAND;
}

static uint16_t handle_set_shipment_state(switch_protocol_t *proto, uint8_t *response) {
    response[14] = ACK_STANDARD;
    response[15] = SUBCMD_SET_SHIPMENT_STATE;
    return INPUT_REPORT_SIZE_SUBCOMMAND;
}

static uint16_t handle_spi_flash_read(switch_protocol_t *proto, const uint8_t *data, uint8_t *response) {
    uint32_t offset = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
    uint8_t size = data[4];

    if (size > 0x1D) {
        size = 0x1D;
    }

    response[14] = ACK_SPI_READ;
    response[15] = SUBCMD_SPI_FLASH_READ;

    response[16] = offset & 0xFF;
    response[17] = (offset >> 8) & 0xFF;
    response[18] = (offset >> 16) & 0xFF;
    response[19] = (offset >> 24) & 0xFF;
    response[20] = size;

    spi_flash_read(offset, &response[21], size);

    return INPUT_REPORT_SIZE_SUBCOMMAND;
}

static uint16_t handle_set_nfc_ir_mcu_config(switch_protocol_t *proto, const uint8_t *data, uint8_t *response) {
    uint8_t config_mode = data[2];
    if (config_mode == MCU_STATE_CONFIGURED_NFC) {
        proto->mcu_state = MCU_STATE_CONFIGURED_NFC;
        proto->nfc_state = NFC_STATE_NONE;
        proto->nfc_seq = 0;
        proto->last_poll_uid_valid = false;
    } else if (config_mode == MCU_STATE_READY) {
        proto->mcu_state = MCU_STATE_READY;
    }

    response[14] = ACK_MCU_CONFIG;
    response[15] = SUBCMD_SET_NFC_IR_MCU_CONFIG;

    static const uint8_t mcu_response[] = {
        0x01, 0x00, 0xFF, 0x00, 0x08, 0x00, 0x1B, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0xC8
    };

    memcpy(&response[16], mcu_response, sizeof(mcu_response));

    return INPUT_REPORT_SIZE_SUBCOMMAND;
}

static uint16_t handle_set_nfc_ir_mcu_state(switch_protocol_t *proto, const uint8_t *data, uint8_t *response) {
    if (data[0] == 0x00) {
        proto->mcu_state = MCU_STATE_SUSPENDED;
        proto->nfc_state = NFC_STATE_NONE;
        proto->last_poll_uid_valid = false;
    } else if (data[0] == 0x01) {
        proto->mcu_state = MCU_STATE_READY;
    }

    response[14] = ACK_STANDARD;
    response[15] = SUBCMD_SET_NFC_IR_MCU_STATE;
    return INPUT_REPORT_SIZE_SUBCOMMAND;
}

static uint16_t handle_set_player_lights(switch_protocol_t *proto, const uint8_t *data, uint8_t *response) {
    proto->player_lights_received = true;
    proto->player_number = data[0];
    proto->state = PROTO_STATE_CONNECTED;

    pico_log_noticef("Player lights set to %d, state -> CONNECTED", proto->player_number);

    response[14] = ACK_STANDARD;
    response[15] = SUBCMD_SET_PLAYER_LIGHTS;

    return INPUT_REPORT_SIZE_SUBCOMMAND;
}

static uint16_t handle_enable_6axis_sensor(switch_protocol_t *proto, uint8_t *response) {
    response[14] = ACK_STANDARD;
    response[15] = SUBCMD_ENABLE_6AXIS_SENSOR;
    return INPUT_REPORT_SIZE_SUBCOMMAND;
}

static uint16_t handle_enable_vibration(switch_protocol_t *proto, uint8_t *response) {
    response[14] = ACK_STANDARD;
    response[15] = SUBCMD_ENABLE_VIBRATION;
    return INPUT_REPORT_SIZE_SUBCOMMAND;
}

static void build_mcu_crc(uint8_t *mcu_data) {
    mcu_data[MCU_DATA_SIZE - 1] = crc8(mcu_data, MCU_DATA_SIZE - 1);
}

static void build_mcu_idle_response(uint8_t *mcu_data) {
    memset(mcu_data, 0, MCU_DATA_SIZE);
    mcu_data[0] = 0xFF;
    build_mcu_crc(mcu_data);
}

static void build_mcu_status_response(switch_protocol_t *proto, uint8_t *mcu_data) {
    memset(mcu_data, 0, MCU_DATA_SIZE);
    mcu_data[0] = 0x01;
    mcu_data[1] = 0x00;
    mcu_data[2] = 0x00;
    mcu_data[3] = 0x00;
    mcu_data[4] = 0x08;
    mcu_data[5] = 0x00;
    mcu_data[6] = 0x1B;
    mcu_data[7] = proto->mcu_state;
    build_mcu_crc(mcu_data);
}

static void build_nfc_status_response(switch_protocol_t *proto, uint8_t *mcu_data) {
    if (proto->nfc_state == NFC_STATE_POLL && proto->amiibo_loaded) {
        if (proto->last_poll_uid_valid &&
            memcmp(proto->amiibo_uid, proto->last_poll_uid, 7) == 0) {
            proto->nfc_state = NFC_STATE_POLL_AGAIN;
        } else {
            memcpy(proto->last_poll_uid, proto->amiibo_uid, 7);
            proto->last_poll_uid_valid = true;
        }
    } else if (proto->nfc_state == NFC_STATE_POLL_AGAIN) {
        if (!proto->amiibo_loaded ||
            memcmp(proto->amiibo_uid, proto->last_poll_uid, 7) != 0) {
            proto->nfc_state = NFC_STATE_POLL;
            if (proto->amiibo_loaded) {
                memcpy(proto->last_poll_uid, proto->amiibo_uid, 7);
                proto->last_poll_uid_valid = true;
            } else {
                proto->last_poll_uid_valid = false;
            }
        }
    }

    memset(mcu_data, 0, MCU_DATA_SIZE);
    mcu_data[0] = 0x2A;
    mcu_data[1] = 0x00;
    mcu_data[2] = 0x05;
    mcu_data[3] = proto->nfc_seq;
    mcu_data[4] = 0x00;
    mcu_data[5] = 0x09;
    mcu_data[6] = 0x31;
    mcu_data[7] = proto->nfc_state;

    if (proto->amiibo_loaded && proto->nfc_state >= NFC_STATE_POLL) {
        mcu_data[8] = 0x00;
        mcu_data[9] = 0x00;
        mcu_data[10] = 0x00;
        mcu_data[11] = 0x01;
        mcu_data[12] = 0x01;
        mcu_data[13] = 0x02;
        mcu_data[14] = 0x00;
        mcu_data[15] = 0x07;
        memcpy(&mcu_data[16], proto->amiibo_uid, 7);
    }

    build_mcu_crc(mcu_data);
}

static void build_nfc_read_packet1(switch_protocol_t *proto, uint8_t *mcu_data) {
    memset(mcu_data, 0, MCU_DATA_SIZE);

    static const uint8_t header[] = {
        0x3a, 0x00, 0x07, 0x01, 0x00, 0x01, 0x31, 0x02,
        0x00, 0x00, 0x00, 0x01, 0x02, 0x00, 0x07
    };
    memcpy(mcu_data, header, sizeof(header));

    memcpy(&mcu_data[15], proto->amiibo_uid, 7);

    static const uint8_t fixed_data[] = {
        0x00, 0x00, 0x00, 0x00, 0x7D, 0xFD, 0xF0, 0x79,
        0x36, 0x51, 0xAB, 0xD7, 0x46, 0x6E, 0x39, 0xC1,
        0x91, 0xBA, 0xBE, 0xB8, 0x56, 0xCE, 0xED, 0xF1,
        0xCE, 0x44, 0xCC, 0x75, 0xEA, 0xFB, 0x27, 0x09,
        0x4D, 0x08, 0x7A, 0xE8, 0x03, 0x00, 0x3B, 0x3C,
        0x77, 0x78, 0x86, 0x00, 0x00
    };
    memcpy(&mcu_data[22], fixed_data, sizeof(fixed_data));

    if (proto->amiibo_data != NULL && proto->amiibo_size >= 245) {
        memcpy(&mcu_data[67], proto->amiibo_data, 245);
    }

    build_mcu_crc(mcu_data);
}

static void build_nfc_read_packet2(switch_protocol_t *proto, uint8_t *mcu_data) {
    memset(mcu_data, 0, MCU_DATA_SIZE);

    static const uint8_t header[] = {
        0x3a, 0x00, 0x07, 0x02, 0x00, 0x09, 0x27
    };
    memcpy(mcu_data, header, sizeof(header));

    if (proto->amiibo_data != NULL && proto->amiibo_size > 245) {
        memcpy(&mcu_data[7], proto->amiibo_data + 245, 295);
    }

    build_mcu_crc(mcu_data);
}

static void build_nfc_read_finished(switch_protocol_t *proto, uint8_t *mcu_data) {
    memset(mcu_data, 0, MCU_DATA_SIZE);

    static const uint8_t header[] = {
        0x2a, 0x00, 0x05, 0x00, 0x00, 0x09, 0x31, 0x04,
        0x00, 0x00, 0x00, 0x01, 0x01, 0x02, 0x00, 0x07
    };
    memcpy(mcu_data, header, sizeof(header));

    memcpy(&mcu_data[16], proto->amiibo_uid, 7);

    build_mcu_crc(mcu_data);
}

static void build_mcu_response_for_state(switch_protocol_t *proto, uint8_t *mcu_data, bool advance_read) {
    switch (proto->nfc_state) {
        case NFC_STATE_NONE:
            if (proto->mcu_state == MCU_STATE_SUSPENDED) {
                build_mcu_idle_response(mcu_data);
            } else if (proto->mcu_state == MCU_STATE_CONFIGURED_NFC) {
                if (proto->last_mcu_cmd == 0x02) {
                    build_nfc_status_response(proto, mcu_data);
                } else {
                    build_mcu_status_response(proto, mcu_data);
                }
            } else {
                build_mcu_status_response(proto, mcu_data);
            }
            break;

        case NFC_STATE_POLL:
        case NFC_STATE_POLL_AGAIN:
            build_nfc_status_response(proto, mcu_data);
            break;

        case NFC_STATE_PENDING_READ:
            if (advance_read) {
                proto->nfc_state = NFC_STATE_READING;
                proto->nfc_read_stage = 1;
                build_nfc_read_packet1(proto, mcu_data);
            } else {
                build_nfc_status_response(proto, mcu_data);
            }
            break;

        case NFC_STATE_READING:
            if (advance_read) {
                if (proto->nfc_read_stage == 1) {
                    proto->nfc_read_stage = 2;
                    build_nfc_read_packet2(proto, mcu_data);
                } else {
                    build_nfc_read_finished(proto, mcu_data);
                    proto->nfc_state = NFC_STATE_POLL_AGAIN;
                }
            } else {
                build_nfc_status_response(proto, mcu_data);
            }
            break;
    }
    memcpy(proto->last_mcu_response, mcu_data, 24);
}

static bool handle_mcu_request(switch_protocol_t *proto, const uint8_t *data, uint16_t len) {
    if (len < 12) return false;

    uint8_t mcu_cmd = data[11];
    uint8_t mcu_subcmd = (len > 12) ? data[12] : 0;

    proto->last_mcu_cmd = mcu_cmd;
    proto->last_mcu_subcmd = mcu_subcmd;
    proto->mcu_request_count++;

    uint16_t copy_len = (len > 11) ? len - 11 : 0;
    if (copy_len > 16) copy_len = 16;
    memset(proto->last_mcu_request, 0, 16);
    if (copy_len > 0) {
        memcpy(proto->last_mcu_request, &data[11], copy_len);
    }

    if (mcu_cmd == 0x01) {
        return true;
    }

    if (mcu_cmd == 0x02) {
        switch (mcu_subcmd) {
            case NFC_CMD_START_POLL:
                proto->nfc_state = NFC_STATE_POLL;
                return true;

            case NFC_CMD_STOP_POLL:
                if (proto->nfc_state != NFC_STATE_PENDING_READ &&
                    proto->nfc_state != NFC_STATE_READING) {
                    proto->nfc_state = NFC_STATE_NONE;
                    proto->last_poll_uid_valid = false;
                }
                return true;

            case NFC_CMD_STATUS:
                return true;

            case NFC_CMD_READ_WRITE:
                if (proto->amiibo_loaded) {
                    proto->nfc_state = NFC_STATE_PENDING_READ;
                    proto->nfc_read_stage = 0;
                }
                return true;
        }
    }

    return true;
}

void switch_protocol_init(switch_protocol_t *proto, controller_state_t *controller, const uint8_t *mac) {
    memset(proto, 0, sizeof(*proto));
    proto->state = PROTO_STATE_DISCONNECTED;
    proto->controller = controller;
    memcpy(proto->mac_address, mac, 6);
    proto->input_report_mode = INPUT_REPORT_ID_SIMPLE;
}

void switch_protocol_set_connected(switch_protocol_t *proto, bool is_reconnect) {
    proto->state = is_reconnect ? PROTO_STATE_CONNECTED : PROTO_STATE_PAIRING;
    proto->timer = 0;
    proto->timer_start_ms = 0;
    proto->player_lights_received = is_reconnect;

    pico_log_noticef("Protocol connected: is_reconnect=%d, state=%s",
                   is_reconnect,
                   is_reconnect ? "CONNECTED" : "PAIRING");
}

void switch_protocol_set_disconnected(switch_protocol_t *proto) {
    proto->state = PROTO_STATE_DISCONNECTED;
    proto->player_lights_received = false;
}

uint16_t switch_protocol_build_input_report(switch_protocol_t *proto, uint8_t *buffer, uint16_t max_size) {
    uint8_t mode = proto->input_report_mode;

    if (mode == INPUT_REPORT_ID_SIMPLE) {
        if (max_size < 12) return 0;

        buffer[0] = HID_REPORT_INPUT;
        buffer[1] = INPUT_REPORT_ID_SIMPLE;
        buffer[2] = 0x28;
        buffer[3] = 0xCA;
        buffer[4] = 0x08;
        buffer[5] = 0x40;
        buffer[6] = 0x8A;
        buffer[7] = 0x4F;
        buffer[8] = 0x8A;
        buffer[9] = 0xD0;
        buffer[10] = 0x7E;
        buffer[11] = 0xDF;

        return 12;
    }

    if (mode == INPUT_REPORT_ID_IMU) {
        if (max_size < INPUT_REPORT_SIZE_IMU) return 0;

        memset(buffer, 0, INPUT_REPORT_SIZE_IMU);
        build_report_header(proto, buffer, INPUT_REPORT_ID_IMU);

        return INPUT_REPORT_SIZE_IMU;
    }

    if (mode == INPUT_REPORT_ID_MCU) {
        if (max_size < INPUT_REPORT_SIZE_MCU) return 0;

        memset(buffer, 0, INPUT_REPORT_SIZE_MCU);
        build_report_header(proto, buffer, INPUT_REPORT_ID_MCU);

        uint8_t *mcu_data = &buffer[MCU_DATA_OFFSET];
        build_mcu_response_for_state(proto, mcu_data, true);

        return INPUT_REPORT_SIZE_MCU;
    }

    if (max_size < INPUT_REPORT_SIZE_SUBCOMMAND) return 0;
    memset(buffer, 0, INPUT_REPORT_SIZE_SUBCOMMAND);
    build_report_header(proto, buffer, INPUT_REPORT_ID_SUBCOMMAND);

    return INPUT_REPORT_SIZE_SUBCOMMAND;
}

uint16_t switch_protocol_build_empty_report(switch_protocol_t *proto, uint8_t *buffer, uint16_t max_size) {
    if (max_size < INPUT_REPORT_SIZE_SUBCOMMAND) return 0;

    memset(buffer, 0, INPUT_REPORT_SIZE_SUBCOMMAND);
    buffer[0] = HID_REPORT_INPUT;
    buffer[1] = INPUT_REPORT_ID_SUBCOMMAND;

    return INPUT_REPORT_SIZE_SUBCOMMAND;
}

bool switch_protocol_handle_output_report(switch_protocol_t *proto, const uint8_t *data, uint16_t len,
                                          uint8_t *response, uint16_t *response_len) {
    if (len < 2) {
        return false;
    }

    if (data[0] != HID_REPORT_OUTPUT) {
        return false;
    }

    uint8_t report_id = data[1];
    proto->last_output_report_id = report_id;

    memset(response, 0, INPUT_REPORT_SIZE_SUBCOMMAND);
    build_report_header(proto, response, INPUT_REPORT_ID_SUBCOMMAND);

    if (report_id == OUTPUT_REPORT_ID_SUBCOMMAND) {
        if (len < 12) {
            return false;
        }

        uint8_t subcmd = data[11];
        const uint8_t *subcmd_data = &data[12];

        switch (subcmd) {
            case SUBCMD_REQUEST_DEVICE_INFO:
                *response_len = handle_request_device_info(proto, response);
                break;

            case SUBCMD_SET_INPUT_REPORT_MODE:
                *response_len = handle_set_input_report_mode(proto, subcmd_data, response);
                break;

            case SUBCMD_TRIGGER_BUTTONS_TIME:
                *response_len = handle_trigger_buttons_time(proto, response);
                break;

            case SUBCMD_SET_SHIPMENT_STATE:
                *response_len = handle_set_shipment_state(proto, response);
                break;

            case SUBCMD_SPI_FLASH_READ:
                *response_len = handle_spi_flash_read(proto, subcmd_data, response);
                break;

            case SUBCMD_SET_NFC_IR_MCU_CONFIG:
                *response_len = handle_set_nfc_ir_mcu_config(proto, subcmd_data, response);
                break;

            case SUBCMD_SET_NFC_IR_MCU_STATE:
                *response_len = handle_set_nfc_ir_mcu_state(proto, subcmd_data, response);
                break;

            case SUBCMD_SET_PLAYER_LIGHTS:
                *response_len = handle_set_player_lights(proto, subcmd_data, response);
                break;

            case SUBCMD_ENABLE_6AXIS_SENSOR:
                *response_len = handle_enable_6axis_sensor(proto, response);
                break;

            case SUBCMD_ENABLE_VIBRATION:
                *response_len = handle_enable_vibration(proto, response);
                break;

            default:
                return false;
        }

        return true;
    }

    if (report_id == OUTPUT_REPORT_ID_RUMBLE) {
        return false;
    }

    if (report_id == OUTPUT_REPORT_ID_MCU_REQUEST) {
        return handle_mcu_request(proto, data, len);
    }

    return false;
}

bool switch_protocol_is_ready_for_input(const switch_protocol_t *proto) {
    return proto->state == PROTO_STATE_CONNECTED && proto->player_lights_received;
}

uint32_t switch_protocol_get_send_interval_ms(const switch_protocol_t *proto) {
    if (proto->state == PROTO_STATE_PAIRING) {
        if (proto->input_report_mode == INPUT_REPORT_ID_SIMPLE) {
            return 1000;
        }
        return 67;
    }

    if (proto->state == PROTO_STATE_CONNECTED) {
        return 17;
    }

    return 1000;
}

uint8_t switch_protocol_get_player_number(const switch_protocol_t *proto) {
    return proto->player_lights_received ? proto->player_number : 0xFF;
}

void switch_protocol_update_timer(switch_protocol_t *proto, uint32_t current_time_ms) {
    if (proto->timer_start_ms == 0) {
        proto->timer_start_ms = current_time_ms;
    }

    uint32_t elapsed = current_time_ms - proto->timer_start_ms;
    proto->timer = (elapsed / 5) & 0xFF;
}

void switch_protocol_set_amiibo(switch_protocol_t *proto, const uint8_t *data, uint16_t size) {
    proto->amiibo_data = data;
    proto->amiibo_size = size;
    proto->amiibo_loaded = true;

    if (data != NULL && size >= 9) {
        proto->amiibo_uid[0] = data[0];
        proto->amiibo_uid[1] = data[1];
        proto->amiibo_uid[2] = data[2];
        proto->amiibo_uid[3] = data[4];
        proto->amiibo_uid[4] = data[5];
        proto->amiibo_uid[5] = data[6];
        proto->amiibo_uid[6] = data[7];
    }
}

void switch_protocol_clear_amiibo(switch_protocol_t *proto) {
    proto->amiibo_data = NULL;
    proto->amiibo_size = 0;
    proto->amiibo_loaded = false;
    memset(proto->amiibo_uid, 0, sizeof(proto->amiibo_uid));
}
