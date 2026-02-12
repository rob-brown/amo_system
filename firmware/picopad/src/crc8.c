#include "crc8.h"

uint8_t crc8_update(uint8_t crc, uint8_t byte) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
        if (crc & 0x80) {
            crc = (crc << 1) ^ CRC8_POLYNOMIAL;
        } else {
            crc <<= 1;
        }
    }
    return crc;
}

uint8_t crc8(const uint8_t *data, size_t length) {
    if (data == NULL) {
        return CRC8_INIT;
    }
    uint8_t crc = CRC8_INIT;
    for (size_t i = 0; i < length; i++) {
        crc = crc8_update(crc, data[i]);
    }
    return crc;
}
