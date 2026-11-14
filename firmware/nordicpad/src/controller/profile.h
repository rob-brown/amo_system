#ifndef CONTROLLER_PROFILE_H
#define CONTROLLER_PROFILE_H

#include <stddef.h>
#include <stdint.h>

#include "controller/identity.h"
#include "controller/input_report.h"

#define ADVERTISING_DATA_MAX_SIZE 31
#define COLOR_SIZE 3
#define VERSION_SIZE 3

typedef enum {
    CONTROLLER_TYPE_JOYCON_L = 0,
    CONTROLLER_TYPE_JOYCON_R = 1,
    CONTROLLER_TYPE_PRO_CONTROLLER = 2
} controller_type_t;

typedef struct {
    uint8_t body[COLOR_SIZE];
    uint8_t buttons[COLOR_SIZE];
    uint8_t highlight[COLOR_SIZE];
    uint8_t grip[COLOR_SIZE];
} controller_colors_t;

typedef struct {
    const char *name;
    uint8_t address[6];
    controller_type_t type;
    uint8_t dsp_firmware_version[VERSION_SIZE];
    const static_reply_t *extra_replies;
    size_t extra_reply_count;
    const memory_region_t *memory_overrides;
    size_t memory_override_count;
    uint16_t product_id;
    uint8_t hardware_variant[VERSION_SIZE];
    char serial_prefix[3];
    char serial_digits[11];
    controller_colors_t colors;
    const input_layout_t *input_layout;
    size_t command_prefix_size;
    uint8_t advertising_data[ADVERTISING_DATA_MAX_SIZE];
    size_t advertising_data_length;
    size_t advertising_host_address_offset;
    uint8_t scan_response_data[ADVERTISING_DATA_MAX_SIZE];
    size_t scan_response_length;
} controller_profile_t;

extern const controller_profile_t JOYCON_R_PROFILE;
extern const controller_profile_t PRO_CONTROLLER_PROFILE;

#endif
