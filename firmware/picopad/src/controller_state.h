#ifndef CONTROLLER_STATE_H
#define CONTROLLER_STATE_H

#include <stdint.h>
#include <stdbool.h>

typedef enum {
    CONTROLLER_JOYCON_L = 0x01,
    CONTROLLER_JOYCON_R = 0x02,
    CONTROLLER_PRO = 0x03
} controller_type_t;

typedef enum {
    BTN_Y = 0,
    BTN_X = 1,
    BTN_B = 2,
    BTN_A = 3,
    BTN_SR_R = 4,
    BTN_SL_R = 5,
    BTN_R = 6,
    BTN_ZR = 7,
    BTN_MINUS = 8,
    BTN_PLUS = 9,
    BTN_R_STICK = 10,
    BTN_L_STICK = 11,
    BTN_HOME = 12,
    BTN_CAPTURE = 13,
    BTN_DOWN = 16,
    BTN_UP = 17,
    BTN_RIGHT = 18,
    BTN_LEFT = 19,
    BTN_SR_L = 20,
    BTN_SL_L = 21,
    BTN_L = 22,
    BTN_ZL = 23
} button_t;

typedef struct {
    uint16_t h;
    uint16_t v;
} stick_state_t;

typedef struct {
    uint16_t h_center;
    uint16_t v_center;
    uint16_t h_max_above;
    uint16_t v_max_above;
    uint16_t h_max_below;
    uint16_t v_max_below;
} stick_calibration_t;

typedef struct {
    controller_type_t type;
    uint8_t buttons[3];
    stick_state_t left_stick;
    stick_state_t right_stick;
    stick_calibration_t left_cal;
    stick_calibration_t right_cal;
} controller_state_t;

void controller_state_init(controller_state_t *state, controller_type_t type);

void controller_set_button(controller_state_t *state, button_t button, bool pressed);
bool controller_get_button(const controller_state_t *state, button_t button);
void controller_clear_buttons(controller_state_t *state);

void controller_set_stick(controller_state_t *state, bool left, uint16_t h, uint16_t v);
void controller_set_stick_center(controller_state_t *state, bool left);
void controller_set_stick_up(controller_state_t *state, bool left);
void controller_set_stick_down(controller_state_t *state, bool left);
void controller_set_stick_left(controller_state_t *state, bool left);
void controller_set_stick_right(controller_state_t *state, bool left);

void controller_encode_stick(const stick_state_t *stick, uint8_t *out);
void controller_decode_stick(const uint8_t *data, stick_state_t *stick);

const char *controller_get_name(controller_type_t type);

#endif
