#ifndef CRC8_H
#define CRC8_H

#include <stddef.h>
#include <stdint.h>

#define CRC8_POLYNOMIAL 0x07
#define CRC8_INIT 0x00

uint8_t crc8(const uint8_t *data, size_t length);
uint8_t crc8_update(uint8_t crc, uint8_t byte);

#endif
