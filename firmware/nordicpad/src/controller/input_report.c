#include "controller/input_report.h"

#include <string.h>

#define COUNTER_OFFSET 0

static const uint8_t JOYCON_R_IDLE[INPUT_REPORT_SIZE] = {
    0x00, 0x18, 0x00, 0x00, 0x07, 0x13, 0xE8, 0x7A, 0x38, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00,
};

static const uint8_t PRO_CONTROLLER_IDLE[INPUT_REPORT_SIZE] = {
    0x00, 0x18, 0x00, 0x00, 0x00, 0x13, 0xE8, 0x7A, 0x13, 0xE8, 0x7A, 0x30, 0x00, 0x00, 0x28,
};

static const button_map_entry_t JOYCON_R_BUTTONS[] = {
    {BUTTON_B, 0, 0x01},    {BUTTON_A, 0, 0x02},  {BUTTON_Y, 0, 0x04},  {BUTTON_X, 0, 0x08},
    {BUTTON_R, 0, 0x10},    {BUTTON_ZR, 0, 0x20}, {BUTTON_PLUS, 0, 0x40}, {BUTTON_STICK, 0, 0x80},
    {BUTTON_HOME, 1, 0x01}, {BUTTON_C, 1, 0x10},  {BUTTON_SR, 1, 0x40},  {BUTTON_SL, 1, 0x80},
};

static const button_map_entry_t PRO_CONTROLLER_BUTTONS[] = {
    {BUTTON_B, 0, 0x01},           {BUTTON_A, 0, 0x02},     {BUTTON_Y, 0, 0x04},    {BUTTON_X, 0, 0x08},
    {BUTTON_R, 0, 0x10},           {BUTTON_ZR, 0, 0x20},    {BUTTON_PLUS, 0, 0x40}, {BUTTON_STICK, 0, 0x80},
    {BUTTON_DOWN, 1, 0x01},        {BUTTON_RIGHT, 1, 0x02}, {BUTTON_LEFT, 1, 0x04}, {BUTTON_UP, 1, 0x08},
    {BUTTON_L, 1, 0x10},           {BUTTON_ZL, 1, 0x20},    {BUTTON_MINUS, 1, 0x40}, {BUTTON_LEFT_STICK, 1, 0x80},
    {BUTTON_HOME, 2, 0x01},        {BUTTON_CAPTURE, 2, 0x02}, {BUTTON_C, 2, 0x10},
    {BUTTON_GL, 2, 0x08},          {BUTTON_GR, 2, 0x04},
};

const input_layout_t INPUT_LAYOUT_JOYCON_R = {
    .idle_report = JOYCON_R_IDLE,
    .buttons_offset = 2,
    .buttons = JOYCON_R_BUTTONS,
    .button_count = sizeof(JOYCON_R_BUTTONS) / sizeof(JOYCON_R_BUTTONS[0]),
    .left_stick_offset = STICK_ABSENT,
    .right_stick_offset = 5,
    .nfc_counter_offset = 14,
};

const input_layout_t INPUT_LAYOUT_PRO_CONTROLLER = {
    .idle_report = PRO_CONTROLLER_IDLE,
    .buttons_offset = 2,
    .buttons = PRO_CONTROLLER_BUTTONS,
    .button_count = sizeof(PRO_CONTROLLER_BUTTONS) / sizeof(PRO_CONTROLLER_BUTTONS[0]),
    .left_stick_offset = 5,
    .right_stick_offset = 8,
    .nfc_counter_offset = 12,
};

static void write_stick(uint8_t *out, uint16_t x, uint16_t y) {
    out[0] = (uint8_t)(x & 0xFF);
    out[1] = (uint8_t)(((x >> 8) & 0x0F) | ((y & 0x0F) << 4));
    out[2] = (uint8_t)((y >> 4) & 0xFF);
}

static void write_buttons(const input_layout_t *layout, uint32_t buttons, uint8_t out[INPUT_REPORT_SIZE]) {
    for (size_t index = 0; index < layout->button_count; index++) {
        const button_map_entry_t *entry = &layout->buttons[index];
        if (buttons & entry->logical) {
            out[layout->buttons_offset + entry->byte] |= entry->mask;
        }
    }
}

void input_report_init(input_report_t *report) {
    report->layout = &INPUT_LAYOUT_JOYCON_R;
    report->counter = 0;
    report->buttons = 0;
    report->left_x = STICK_CENTER_X;
    report->left_y = STICK_CENTER_Y;
    report->stick_x = STICK_CENTER_X;
    report->stick_y = STICK_CENTER_Y;
    report->nfc_counter = 0;
}

void input_report_build(input_report_t *report, uint8_t out[INPUT_REPORT_SIZE]) {
    const input_layout_t *layout = report->layout;

    memcpy(out, layout->idle_report, INPUT_REPORT_SIZE);
    out[COUNTER_OFFSET] = report->counter;
    write_buttons(layout, report->buttons, out);
    if (layout->left_stick_offset != STICK_ABSENT) {
        write_stick(&out[layout->left_stick_offset], report->left_x, report->left_y);
    }
    write_stick(&out[layout->right_stick_offset], report->stick_x, report->stick_y);
    out[layout->nfc_counter_offset] = report->nfc_counter;
    report->counter++;
}
