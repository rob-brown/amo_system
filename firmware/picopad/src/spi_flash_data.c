#include "spi_flash_data.h"
#include <string.h>

static const uint8_t default_l_stick_cal[9] = {
    0x00, 0x07, 0x70,
    0x00, 0x08, 0x80,
    0x00, 0x07, 0x70
};

static const uint8_t default_r_stick_cal[9] = {
    0x00, 0x08, 0x80,
    0x00, 0x07, 0x70,
    0x00, 0x07, 0x70
};

static const uint8_t factory_6axis_cal[24] = {
    0x00, 0x40, 0x00, 0x40, 0x00, 0x40,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xD5, 0xFF, 0xD4, 0xFF, 0xD3, 0xFF,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static const uint8_t factory_settings[24] = {
    0x50, 0xFD, 0x00, 0x00, 0xC6, 0x0F,
    0x0F, 0x30, 0x61, 0x96, 0x30, 0xF3,
    0xD4, 0x14, 0x54, 0x41, 0x15, 0x54,
    0xC7, 0x79, 0x9C, 0x33, 0x36, 0x63
};

static const uint8_t stick_params_1[12] = {
    0x0F, 0x30, 0x61, 0x96, 0x30, 0xF3,
    0x0F, 0x30, 0x61, 0x96, 0x30, 0xF3
};

static const uint8_t stick_params_2[18] = {
    0x50, 0xFD, 0x00, 0x00, 0xC6, 0x0F,
    0x50, 0xFD, 0x00, 0x00, 0xC6, 0x0F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static uint8_t color_type = 0x02;
static uint8_t body_color[3] = {0x32, 0x32, 0x32};
static uint8_t button_color[3] = {0xFF, 0xFF, 0xFF};
static uint8_t left_grip_color[3] = {0x32, 0x32, 0x32};
static uint8_t right_grip_color[3] = {0x32, 0x32, 0x32};

void spi_flash_init(void) {
}

bool spi_flash_read(uint32_t address, uint8_t *buffer, size_t size) {
    if (address + size > SPI_FLASH_SIZE) {
        return false;
    }

    memset(buffer, 0xFF, size);

    for (size_t i = 0; i < size; i++) {
        uint32_t addr = address + i;

        if (addr >= SPI_ADDR_FACTORY_L_STICK_CAL &&
            addr < SPI_ADDR_FACTORY_L_STICK_CAL + SPI_STICK_CAL_SIZE) {
            buffer[i] = default_l_stick_cal[addr - SPI_ADDR_FACTORY_L_STICK_CAL];
        }
        else if (addr >= SPI_ADDR_FACTORY_R_STICK_CAL &&
                 addr < SPI_ADDR_FACTORY_R_STICK_CAL + SPI_STICK_CAL_SIZE) {
            buffer[i] = default_r_stick_cal[addr - SPI_ADDR_FACTORY_R_STICK_CAL];
        }
        else if (addr >= SPI_ADDR_FACTORY_6AXIS_CAL &&
                 addr < SPI_ADDR_FACTORY_6AXIS_CAL + sizeof(factory_6axis_cal)) {
            buffer[i] = factory_6axis_cal[addr - SPI_ADDR_FACTORY_6AXIS_CAL];
        }
        else if (addr >= SPI_ADDR_FACTORY_SETTINGS &&
                 addr < SPI_ADDR_FACTORY_SETTINGS + sizeof(factory_settings)) {
            buffer[i] = factory_settings[addr - SPI_ADDR_FACTORY_SETTINGS];
        }
        else if (addr >= 0x6098 && addr < 0x6098 + sizeof(stick_params_1)) {
            buffer[i] = stick_params_1[addr - 0x6098];
        }
        else if (addr >= 0x60A4 && addr < 0x60A4 + sizeof(stick_params_2)) {
            buffer[i] = stick_params_2[addr - 0x60A4];
        }
        else if (addr == SPI_ADDR_COLOR_TYPE) {
            buffer[i] = color_type;
        }
        else if (addr >= SPI_ADDR_BODY_COLOR &&
                 addr < SPI_ADDR_BODY_COLOR + SPI_COLOR_SIZE) {
            buffer[i] = body_color[addr - SPI_ADDR_BODY_COLOR];
        }
        else if (addr >= SPI_ADDR_BUTTON_COLOR &&
                 addr < SPI_ADDR_BUTTON_COLOR + SPI_COLOR_SIZE) {
            buffer[i] = button_color[addr - SPI_ADDR_BUTTON_COLOR];
        }
        else if (addr >= SPI_ADDR_LEFT_GRIP_COLOR &&
                 addr < SPI_ADDR_LEFT_GRIP_COLOR + SPI_COLOR_SIZE) {
            buffer[i] = left_grip_color[addr - SPI_ADDR_LEFT_GRIP_COLOR];
        }
        else if (addr >= SPI_ADDR_RIGHT_GRIP_COLOR &&
                 addr < SPI_ADDR_RIGHT_GRIP_COLOR + SPI_COLOR_SIZE) {
            buffer[i] = right_grip_color[addr - SPI_ADDR_RIGHT_GRIP_COLOR];
        }
    }

    return true;
}

void spi_flash_get_stick_calibration(bool left, bool user, uint8_t *out) {
    if (user) {
        memset(out, 0xFF, SPI_STICK_CAL_SIZE);
    } else {
        memcpy(out, left ? default_l_stick_cal : default_r_stick_cal, SPI_STICK_CAL_SIZE);
    }
}

void spi_flash_set_colors(const uint8_t *body, const uint8_t *buttons,
                          const uint8_t *left_grip, const uint8_t *right_grip) {
    if (body != NULL) {
        memcpy(body_color, body, SPI_COLOR_SIZE);
    }
    if (buttons != NULL) {
        memcpy(button_color, buttons, SPI_COLOR_SIZE);
    }
    if (left_grip != NULL) {
        memcpy(left_grip_color, left_grip, SPI_COLOR_SIZE);
    } else if (body != NULL) {
        memcpy(left_grip_color, body, SPI_COLOR_SIZE);
    }
    if (right_grip != NULL) {
        memcpy(right_grip_color, right_grip, SPI_COLOR_SIZE);
    } else if (body != NULL) {
        memcpy(right_grip_color, body, SPI_COLOR_SIZE);
    }
    color_type = 0x02;
}
