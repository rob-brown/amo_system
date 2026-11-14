#include "controller/controller_input.h"

#include <string.h>

#define STICK_LOW 0
#define STICK_MID 0x800
#define STICK_HIGH STICK_MAX

typedef struct {
    uint8_t byte;
    uint8_t bit;
    uint32_t report_mask;
} bitfield_entry_t;

static const bitfield_entry_t BITFIELD_ENTRIES[] = {
    {0, 0, BUTTON_Y},       {0, 1, BUTTON_X},      {0, 2, BUTTON_B},      {0, 3, BUTTON_A},
    {0, 4, BUTTON_SL},      {0, 5, BUTTON_SR},     {0, 6, BUTTON_R},      {0, 7, BUTTON_ZR},
    {1, 0, BUTTON_MINUS},   {1, 1, BUTTON_PLUS},   {1, 2, BUTTON_STICK},  {1, 3, BUTTON_LEFT_STICK},
    {1, 4, BUTTON_HOME},    {1, 5, BUTTON_CAPTURE}, {1, 6, BUTTON_C},     {2, 0, BUTTON_DOWN},
    {2, 1, BUTTON_UP},      {2, 2, BUTTON_RIGHT},  {2, 3, BUTTON_LEFT},   {2, 6, BUTTON_L},
    {2, 7, BUTTON_ZL},      {1, 7, BUTTON_GL},     {2, 4, BUTTON_GR},
};

static const uint32_t BUTTON_ID_MASKS[CONTROLLER_INPUT_BUTTON_COUNT] = {
    [0x00] = BUTTON_A,     [0x01] = BUTTON_B,     [0x02] = BUTTON_X,    [0x03] = BUTTON_Y,
    [0x04] = BUTTON_L,     [0x05] = BUTTON_R,     [0x06] = BUTTON_ZL,   [0x07] = BUTTON_ZR,
    [0x08] = BUTTON_UP,    [0x09] = BUTTON_DOWN,  [0x0A] = BUTTON_LEFT, [0x0B] = BUTTON_RIGHT,
    [0x0C] = BUTTON_PLUS,  [0x0D] = BUTTON_MINUS, [0x0E] = BUTTON_HOME, [0x0F] = BUTTON_CAPTURE,
    [0x10] = BUTTON_LEFT_STICK, [0x11] = BUTTON_STICK, [0x12] = BUTTON_SL, [0x13] = BUTTON_SR,
    [0x14] = BUTTON_C,     [0x15] = BUTTON_GL,    [0x16] = BUTTON_GR,
};

typedef struct {
    uint16_t horizontal;
    uint16_t vertical;
} stick_position_t;

static const stick_position_t PRESETS[] = {
    [HOST_PRESET_CENTER] = {STICK_MID, STICK_MID},
    [HOST_PRESET_UP] = {STICK_MID, STICK_HIGH},
    [HOST_PRESET_DOWN] = {STICK_MID, STICK_LOW},
    [HOST_PRESET_LEFT] = {STICK_LOW, STICK_MID},
    [HOST_PRESET_RIGHT] = {STICK_HIGH, STICK_MID},
    [HOST_PRESET_UP_LEFT] = {STICK_LOW, STICK_HIGH},
    [HOST_PRESET_UP_RIGHT] = {STICK_HIGH, STICK_HIGH},
    [HOST_PRESET_DOWN_LEFT] = {STICK_LOW, STICK_LOW},
    [HOST_PRESET_DOWN_RIGHT] = {STICK_HIGH, STICK_LOW},
};

static uint16_t clamp_stick(uint16_t value) {
    return value > STICK_MAX ? STICK_MAX : value;
}

static uint32_t held_report_mask(const controller_input_t *input) {
    uint32_t mask = 0;
    for (size_t index = 0; index < sizeof(BITFIELD_ENTRIES) / sizeof(BITFIELD_ENTRIES[0]); index++) {
        const bitfield_entry_t *entry = &BITFIELD_ENTRIES[index];
        if (input->held[entry->byte] & (1u << entry->bit)) {
            mask |= entry->report_mask;
        }
    }
    return mask;
}

static uint32_t pressed_report_mask(const controller_input_t *input) {
    uint32_t mask = 0;
    for (size_t id = 0; id < CONTROLLER_INPUT_BUTTON_COUNT; id++) {
        if (input->press_remaining_ms[id] > 0) {
            mask |= BUTTON_ID_MASKS[id];
        }
    }
    return mask;
}

void controller_input_init(controller_input_t *input) {
    memset(input, 0, sizeof(*input));
    input_report_init(&input->report);
    input->sticks[HOST_STICK_LEFT][0] = STICK_CENTER_X;
    input->sticks[HOST_STICK_LEFT][1] = STICK_CENTER_Y;
    input->sticks[HOST_STICK_RIGHT][0] = STICK_CENTER_X;
    input->sticks[HOST_STICK_RIGHT][1] = STICK_CENTER_Y;
}

void controller_input_set_layout(controller_input_t *input, const input_layout_t *layout) {
    input->report.layout = layout;
}

void controller_input_set_buttons(controller_input_t *input, const uint8_t buttons[CONTROLLER_INPUT_BITFIELD_SIZE],
                                  const uint8_t mask[CONTROLLER_INPUT_BITFIELD_SIZE]) {
    for (size_t index = 0; index < CONTROLLER_INPUT_BITFIELD_SIZE; index++) {
        input->held[index] = (uint8_t)((input->held[index] & ~mask[index]) | (buttons[index] & mask[index]));
    }
}

void controller_input_clear_buttons(controller_input_t *input) {
    memset(input->held, 0, sizeof(input->held));
    memset(input->press_remaining_ms, 0, sizeof(input->press_remaining_ms));
}

bool controller_input_press(controller_input_t *input, uint8_t button_id, uint16_t duration_ms) {
    if (button_id >= CONTROLLER_INPUT_BUTTON_COUNT) {
        return false;
    }
    input->press_remaining_ms[button_id] = duration_ms == 0 ? CONTROLLER_INPUT_DEFAULT_PRESS_MS : duration_ms;
    return true;
}

bool controller_input_set_stick(controller_input_t *input, uint8_t stick, uint16_t horizontal, uint16_t vertical) {
    if (stick >= CONTROLLER_INPUT_STICK_COUNT) {
        return false;
    }
    input->sticks[stick][0] = clamp_stick(horizontal);
    input->sticks[stick][1] = clamp_stick(vertical);
    return true;
}

bool controller_input_set_stick_preset(controller_input_t *input, uint8_t stick, uint8_t preset) {
    if (preset > HOST_PRESET_DOWN_RIGHT) {
        return false;
    }
    if (preset == HOST_PRESET_CENTER) {
        return controller_input_set_stick(input, stick, STICK_CENTER_X, STICK_CENTER_Y);
    }
    return controller_input_set_stick(input, stick, PRESETS[preset].horizontal, PRESETS[preset].vertical);
}

void controller_input_get_state(const controller_input_t *input, uint8_t buttons[CONTROLLER_INPUT_BITFIELD_SIZE],
                                uint16_t sticks[CONTROLLER_INPUT_STICK_COUNT][2]) {
    memcpy(buttons, input->held, CONTROLLER_INPUT_BITFIELD_SIZE);
    memcpy(sticks, input->sticks, sizeof(input->sticks));
}

void controller_input_tick(controller_input_t *input, uint16_t elapsed_ms) {
    for (size_t id = 0; id < CONTROLLER_INPUT_BUTTON_COUNT; id++) {
        uint16_t remaining = input->press_remaining_ms[id];
        input->press_remaining_ms[id] = remaining > elapsed_ms ? (uint16_t)(remaining - elapsed_ms) : 0;
    }
}

void controller_input_set_nfc_counter(controller_input_t *input, uint8_t counter) {
    input->report.nfc_counter = counter;
}

void controller_input_build_report(controller_input_t *input, uint8_t out[INPUT_REPORT_SIZE]) {
    input->report.buttons = held_report_mask(input) | pressed_report_mask(input);
    input->report.left_x = input->sticks[HOST_STICK_LEFT][0];
    input->report.left_y = input->sticks[HOST_STICK_LEFT][1];
    input->report.stick_x = input->sticks[HOST_STICK_RIGHT][0];
    input->report.stick_y = input->sticks[HOST_STICK_RIGHT][1];
    input_report_build(&input->report, out);
}
