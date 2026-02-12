#include "protocol_logger.h"
#include "logging.h"
#include "switch_protocol.h"
#include <stdio.h>
#include <string.h>

void log_hex_dump(const char *label, const uint8_t *data, uint16_t len) {
    if (len == 0) {
        pico_log_infof("%s: (empty)", label);
        return;
    }

    char hex_str[256];
    int offset = 0;

    for (uint16_t i = 0; i < len && offset < 240; i++) {
        offset += snprintf(hex_str + offset, sizeof(hex_str) - offset, "%02X ", data[i]);
        if ((i + 1) % 16 == 0 && i < len - 1) {
            pico_log_infof("%s: %s", label, hex_str);
            offset = 0;
        }
    }

    if (offset > 0) {
        pico_log_infof("%s: %s", label, hex_str);
    }
}

void log_input_report(const uint8_t *data, uint16_t len) {
    if (len == 0) return;

    uint8_t report_id = data[0];

    pico_log_infof("=== INPUT REPORT 0x%02X (len=%d) ===", report_id, len);

    if (report_id == INPUT_REPORT_ID_SUBCOMMAND && len >= 15) {
        uint8_t ack = data[13];
        uint8_t subcmd_reply = data[14];
        pico_log_infof("  ACK: 0x%02X, Subcmd: 0x%02X", ack, subcmd_reply);

        if (len > 15) {
            log_hex_dump("  Reply Data", &data[15], len - 15);
        }
    } else if (report_id == INPUT_REPORT_ID_MCU && len > 50) {
        log_hex_dump("  MCU Data", &data[50], len - 50);
        log_mcu_response(&data[50], len - 50);
    }

    log_hex_dump("  Full Packet", data, len);
}

void log_output_report(const uint8_t *data, uint16_t len) {
    if (len == 0) return;

    uint8_t report_id = data[0];

    pico_log_infof(">>> OUTPUT REPORT 0x%02X (len=%d) >>>", report_id, len);

    if (report_id == OUTPUT_REPORT_ID_SUBCOMMAND && len >= 11) {
        uint8_t subcmd = data[10];
        pico_log_infof("  Subcmd: 0x%02X", subcmd);

        if (len > 11) {
            log_hex_dump("  Data", &data[11], len - 11);
        }
    } else if (report_id == OUTPUT_REPORT_ID_MCU_REQUEST && len >= 11) {
        log_hex_dump("  MCU Request", &data[10], len - 10);
    }

    log_hex_dump("  Full Packet", data, len);
}

void log_mcu_response(const uint8_t *mcu_data, uint16_t len) {
    if (len < 7) return;

    uint8_t mcu_cmd = mcu_data[0];
    uint8_t nfc_state = mcu_data[6];

    pico_log_infof("  MCU_CMD: 0x%02X, NFC_STATE: 0x%02X", mcu_cmd, nfc_state);

    if (mcu_cmd == 0x2A) {
        pico_log_info("  Type: NFC_STATUS");
        if (len >= 23) {
            pico_log_infof("  UID: %02X:%02X:%02X:%02X:%02X:%02X:%02X",
                          mcu_data[16], mcu_data[17], mcu_data[18],
                          mcu_data[19], mcu_data[20], mcu_data[21], mcu_data[22]);
        }
    } else if (mcu_cmd == 0x3A) {
        uint8_t marker = mcu_data[3];
        pico_log_infof("  Type: NFC_PACKET, Marker: 0x%02X", marker);
    }
}

void log_nfc_status(const uint8_t *data, uint16_t len) {
    if (len < 23) return;

    pico_log_info("=== NFC STATUS ===");
    pico_log_infof("  State: %d", data[6]);
    pico_log_infof("  UID: %02X:%02X:%02X:%02X:%02X:%02X:%02X",
                  data[16], data[17], data[18], data[19],
                  data[20], data[21], data[22]);
}

void log_nfc_packet(const uint8_t *data, uint16_t len, uint8_t packet_num) {
    if (len < 7) return;

    uint8_t marker = data[3];
    pico_log_infof("=== NFC PACKET %d ===", packet_num);
    pico_log_infof("  Marker: 0x%02X", marker);
    pico_log_infof("  Length: %d", len);
    log_hex_dump("  Data", &data[7], len - 7);
}
