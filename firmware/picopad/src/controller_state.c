#include "controller_state.h"
#include <string.h>

static const stick_calibration_t default_calibration = {
    .h_center = 0x800,
    .v_center = 0x800,
    .h_max_above = 0x700,
    .v_max_above = 0x700,
    .h_max_below = 0x700,
    .v_max_below = 0x700
};

void controller_state_init(controller_state_t *state, controller_type_t type) {
    memset(state, 0, sizeof(*state));
    state->type = type;
    state->left_cal = default_calibration;
    state->right_cal = default_calibration;
    controller_set_stick_center(state, true);
    controller_set_stick_center(state, false);
}

void controller_set_button(controller_state_t *state, button_t button, bool pressed) {
    uint8_t byte_idx = button / 8;
    uint8_t bit_idx = button % 8;

    if (byte_idx >= 3) {
        return;
    }

    if (pressed) {
        state->buttons[byte_idx] |= (1 << bit_idx);
    } else {
        state->buttons[byte_idx] &= ~(1 << bit_idx);
    }
}

bool controller_get_button(const controller_state_t *state, button_t button) {
    uint8_t byte_idx = button / 8;
    uint8_t bit_idx = button % 8;

    if (byte_idx >= 3) {
        return false;
    }

    return (state->buttons[byte_idx] & (1 << bit_idx)) != 0;
}

void controller_clear_buttons(controller_state_t *state) {
    state->buttons[0] = 0;
    state->buttons[1] = 0;
    state->buttons[2] = 0;
}

void controller_set_stick(controller_state_t *state, bool left, uint16_t h, uint16_t v) {
    if (h > 0xFFF) h = 0xFFF;
    if (v > 0xFFF) v = 0xFFF;

    stick_state_t *stick = left ? &state->left_stick : &state->right_stick;
    stick->h = h;
    stick->v = v;
}

void controller_set_stick_center(controller_state_t *state, bool left) {
    const stick_calibration_t *cal = left ? &state->left_cal : &state->right_cal;
    controller_set_stick(state, left, cal->h_center, cal->v_center);
}

void controller_set_stick_up(controller_state_t *state, bool left) {
    const stick_calibration_t *cal = left ? &state->left_cal : &state->right_cal;
    controller_set_stick(state, left, cal->h_center, cal->v_center + cal->v_max_above);
}

void controller_set_stick_down(controller_state_t *state, bool left) {
    const stick_calibration_t *cal = left ? &state->left_cal : &state->right_cal;
    controller_set_stick(state, left, cal->h_center, cal->v_center - cal->v_max_below);
}

void controller_set_stick_left(controller_state_t *state, bool left) {
    const stick_calibration_t *cal = left ? &state->left_cal : &state->right_cal;
    controller_set_stick(state, left, cal->h_center - cal->h_max_below, cal->v_center);
}

void controller_set_stick_right(controller_state_t *state, bool left) {
    const stick_calibration_t *cal = left ? &state->left_cal : &state->right_cal;
    controller_set_stick(state, left, cal->h_center + cal->h_max_above, cal->v_center);
}

void controller_encode_stick(const stick_state_t *stick, uint8_t *out) {
    out[0] = stick->h & 0xFF;
    out[1] = ((stick->h >> 8) & 0x0F) | ((stick->v & 0x0F) << 4);
    out[2] = (stick->v >> 4) & 0xFF;
}

void controller_decode_stick(const uint8_t *data, stick_state_t *stick) {
    stick->h = data[0] | ((data[1] & 0x0F) << 8);
    stick->v = (data[1] >> 4) | (data[2] << 4);
}

const char *controller_get_name(controller_type_t type) {
    switch (type) {
        case CONTROLLER_JOYCON_L:
            return "Joy-Con (L)";
        case CONTROLLER_JOYCON_R:
            return "Joy-Con (R)";
        case CONTROLLER_PRO:
            return "Pro Controller";
        default:
            return "Unknown";
    }
}
