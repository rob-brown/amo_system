#ifndef CONTROLLER_CONTROLLER_INPUT_H
#define CONTROLLER_CONTROLLER_INPUT_H

#include <stdbool.h>
#include <stdint.h>

#include "controller/input_report.h"
#include "host/host_ids.h"

#define CONTROLLER_INPUT_BUTTON_COUNT 0x17
#define CONTROLLER_INPUT_BITFIELD_SIZE 3
#define CONTROLLER_INPUT_DEFAULT_PRESS_MS 50
#define CONTROLLER_INPUT_STICK_COUNT 2

typedef struct {
    input_report_t report;
    uint8_t held[CONTROLLER_INPUT_BITFIELD_SIZE];
    uint16_t press_remaining_ms[CONTROLLER_INPUT_BUTTON_COUNT];
    uint16_t sticks[CONTROLLER_INPUT_STICK_COUNT][2];
} controller_input_t;

void controller_input_init(controller_input_t *input);

void controller_input_set_layout(controller_input_t *input, const input_layout_t *layout);

void controller_input_set_buttons(controller_input_t *input, const uint8_t buttons[CONTROLLER_INPUT_BITFIELD_SIZE],
                                  const uint8_t mask[CONTROLLER_INPUT_BITFIELD_SIZE]);

void controller_input_clear_buttons(controller_input_t *input);

bool controller_input_press(controller_input_t *input, uint8_t button_id, uint16_t duration_ms);

bool controller_input_set_stick(controller_input_t *input, uint8_t stick, uint16_t horizontal, uint16_t vertical);

bool controller_input_set_stick_preset(controller_input_t *input, uint8_t stick, uint8_t preset);

void controller_input_get_state(const controller_input_t *input, uint8_t buttons[CONTROLLER_INPUT_BITFIELD_SIZE],
                                uint16_t sticks[CONTROLLER_INPUT_STICK_COUNT][2]);

void controller_input_tick(controller_input_t *input, uint16_t elapsed_ms);

void controller_input_set_nfc_counter(controller_input_t *input, uint8_t counter);

void controller_input_build_report(controller_input_t *input, uint8_t out[INPUT_REPORT_SIZE]);

#endif
