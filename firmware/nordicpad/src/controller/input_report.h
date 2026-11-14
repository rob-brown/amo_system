#ifndef CONTROLLER_INPUT_REPORT_H
#define CONTROLLER_INPUT_REPORT_H

#include <stddef.h>
#include <stdint.h>

#define INPUT_REPORT_SIZE 63

#define BUTTON_B 0x00000001u
#define BUTTON_A 0x00000002u
#define BUTTON_Y 0x00000004u
#define BUTTON_X 0x00000008u
#define BUTTON_R 0x00000010u
#define BUTTON_ZR 0x00000020u
#define BUTTON_PLUS 0x00000040u
#define BUTTON_STICK 0x00000080u
#define BUTTON_HOME 0x00000100u
#define BUTTON_C 0x00001000u
#define BUTTON_SR 0x00004000u
#define BUTTON_SL 0x00008000u
#define BUTTON_L 0x00010000u
#define BUTTON_ZL 0x00020000u
#define BUTTON_MINUS 0x00040000u
#define BUTTON_UP 0x00080000u
#define BUTTON_DOWN 0x00100000u
#define BUTTON_LEFT 0x00200000u
#define BUTTON_RIGHT 0x00400000u
#define BUTTON_CAPTURE 0x00800000u
#define BUTTON_LEFT_STICK 0x01000000u
#define BUTTON_GL 0x02000000u
#define BUTTON_GR 0x04000000u

#define STICK_CENTER_X 0x813
#define STICK_CENTER_Y 0x7AE
#define STICK_MAX 0xFFF

#define STICK_ABSENT 0

typedef struct {
    uint32_t logical;
    uint8_t byte;
    uint8_t mask;
} button_map_entry_t;

typedef struct {
    const uint8_t *idle_report;
    size_t buttons_offset;
    const button_map_entry_t *buttons;
    size_t button_count;
    size_t left_stick_offset;
    size_t right_stick_offset;
    size_t nfc_counter_offset;
} input_layout_t;

extern const input_layout_t INPUT_LAYOUT_JOYCON_R;
extern const input_layout_t INPUT_LAYOUT_PRO_CONTROLLER;

typedef struct {
    const input_layout_t *layout;
    uint8_t counter;
    uint32_t buttons;
    uint16_t left_x;
    uint16_t left_y;
    uint16_t stick_x;
    uint16_t stick_y;
    uint8_t nfc_counter;
} input_report_t;

void input_report_init(input_report_t *report);

void input_report_build(input_report_t *report, uint8_t out[INPUT_REPORT_SIZE]);

#endif
