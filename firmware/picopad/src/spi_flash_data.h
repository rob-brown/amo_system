#ifndef SPI_FLASH_DATA_H
#define SPI_FLASH_DATA_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#define SPI_FLASH_SIZE 0x80000

#define SPI_ADDR_FACTORY_L_STICK_CAL 0x603D
#define SPI_ADDR_FACTORY_R_STICK_CAL 0x6046
#define SPI_ADDR_FACTORY_6AXIS_CAL  0x6020
#define SPI_ADDR_FACTORY_SETTINGS   0x6080

#define SPI_ADDR_USER_L_STICK_MAGIC 0x8010
#define SPI_ADDR_USER_L_STICK_CAL   0x8012
#define SPI_ADDR_USER_R_STICK_MAGIC 0x801B
#define SPI_ADDR_USER_R_STICK_CAL   0x801D

#define SPI_STICK_CAL_SIZE 9

#define SPI_USER_CAL_MAGIC_0 0xB2
#define SPI_USER_CAL_MAGIC_1 0xA1

#define SPI_ADDR_COLOR_TYPE       0x601B
#define SPI_ADDR_BODY_COLOR       0x6050
#define SPI_ADDR_BUTTON_COLOR     0x6053
#define SPI_ADDR_LEFT_GRIP_COLOR  0x6056
#define SPI_ADDR_RIGHT_GRIP_COLOR 0x6059
#define SPI_COLOR_SIZE 3

void spi_flash_init(void);

bool spi_flash_read(uint32_t address, uint8_t *buffer, size_t size);

void spi_flash_get_stick_calibration(bool left, bool user, uint8_t *out);

void spi_flash_set_colors(const uint8_t *body, const uint8_t *buttons,
                          const uint8_t *left_grip, const uint8_t *right_grip);

#endif
