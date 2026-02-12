#ifndef PROTOCOL_LOGGER_H
#define PROTOCOL_LOGGER_H

#include <stdint.h>

void log_hex_dump(const char *label, const uint8_t *data, uint16_t len);
void log_input_report(const uint8_t *data, uint16_t len);
void log_output_report(const uint8_t *data, uint16_t len);
void log_mcu_response(const uint8_t *mcu_data, uint16_t len);
void log_nfc_status(const uint8_t *data, uint16_t len);
void log_nfc_packet(const uint8_t *data, uint16_t len, uint8_t packet_num);

#endif
