#include "test_framework.h"

#include "controller/controller_input.h"

static const uint8_t NO_BITS[CONTROLLER_INPUT_BITFIELD_SIZE] = {0, 0, 0};
static const uint8_t ALL_BITS[CONTROLLER_INPUT_BITFIELD_SIZE] = {0xFF, 0xFF, 0xFF};

static bool test_idle_input_matches_the_captured_idle_report(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    controller_input_build_report(&input, out);

    // Assert
    ASSERT_EQ(out[2], 0x00);
    ASSERT_EQ(out[3], 0x00);
    ASSERT_MEM_EQ(&out[5], ((const uint8_t[]){0x13, 0xE8, 0x7A}), 3);
    return true;
}

static bool test_held_button_bits_map_to_the_report(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    const uint8_t a_and_home[CONTROLLER_INPUT_BITFIELD_SIZE] = {1 << 3, 1 << 4, 0};
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    controller_input_set_buttons(&input, a_and_home, ALL_BITS);
    controller_input_build_report(&input, out);

    // Assert
    ASSERT_EQ(out[2], 0x02);
    ASSERT_EQ(out[3], 0x01);
    return true;
}

static bool test_mask_limits_which_bits_change(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    const uint8_t a_and_b[CONTROLLER_INPUT_BITFIELD_SIZE] = {(1 << 3) | (1 << 2), 0, 0};
    const uint8_t only_a[CONTROLLER_INPUT_BITFIELD_SIZE] = {1 << 3, 0, 0};
    uint8_t buttons[CONTROLLER_INPUT_BITFIELD_SIZE];
    uint16_t sticks[CONTROLLER_INPUT_STICK_COUNT][2];
    controller_input_set_buttons(&input, a_and_b, ALL_BITS);

    // Act
    controller_input_set_buttons(&input, NO_BITS, only_a);
    controller_input_get_state(&input, buttons, sticks);

    // Assert
    ASSERT_EQ(buttons[0], 1 << 2);
    return true;
}

static bool test_buttons_the_joycon_lacks_never_reach_the_report(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    controller_input_set_buttons(&input, ((const uint8_t[]){0, 0x01 | 0x08 | 0x20, 0xFF}), ALL_BITS);
    controller_input_build_report(&input, out);

    // Assert
    ASSERT_EQ(out[2], 0x00);
    ASSERT_EQ(out[3], 0x00);
    return true;
}

static bool test_timed_press_releases_after_its_duration(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    uint8_t during[INPUT_REPORT_SIZE];
    uint8_t after[INPUT_REPORT_SIZE];

    // Act
    bool accepted = controller_input_press(&input, 0x00, 30);
    controller_input_tick(&input, 15);
    controller_input_build_report(&input, during);
    controller_input_tick(&input, 15);
    controller_input_build_report(&input, after);

    // Assert
    ASSERT(accepted);
    ASSERT_EQ(during[2], 0x02);
    ASSERT_EQ(after[2], 0x00);
    return true;
}

static bool test_zero_duration_uses_the_default_press_time(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    controller_input_press(&input, 0x00, 0);
    controller_input_tick(&input, CONTROLLER_INPUT_DEFAULT_PRESS_MS - 1);
    controller_input_build_report(&input, out);

    // Assert
    ASSERT_EQ(out[2], 0x02);
    return true;
}

static bool test_switch_two_only_buttons_can_be_pressed_by_id(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    controller_input_press(&input, 0x12, 100);
    controller_input_press(&input, 0x13, 100);
    controller_input_build_report(&input, out);

    // Assert
    ASSERT_EQ(out[3], 0xC0);
    return true;
}

static bool test_unknown_button_id_is_rejected(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);

    // Act
    bool accepted = controller_input_press(&input, CONTROLLER_INPUT_BUTTON_COUNT, 10);

    // Assert
    ASSERT(!accepted);
    return true;
}

static bool test_clear_releases_held_and_pressed_buttons(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    uint8_t out[INPUT_REPORT_SIZE];
    controller_input_set_buttons(&input, ALL_BITS, ALL_BITS);
    controller_input_press(&input, 0x00, 1000);

    // Act
    controller_input_clear_buttons(&input);
    controller_input_build_report(&input, out);

    // Assert
    ASSERT_EQ(out[2], 0x00);
    ASSERT_EQ(out[3], 0x00);
    return true;
}

static bool test_right_stick_values_are_packed_into_the_report(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    controller_input_set_stick(&input, HOST_STICK_RIGHT, 0xABC, 0x123);
    controller_input_build_report(&input, out);

    // Assert
    ASSERT_MEM_EQ(&out[5], ((const uint8_t[]){0xBC, 0x3A, 0x12}), 3);
    return true;
}

static bool test_stick_values_are_clamped_to_twelve_bits(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    uint8_t buttons[CONTROLLER_INPUT_BITFIELD_SIZE];
    uint16_t sticks[CONTROLLER_INPUT_STICK_COUNT][2];

    // Act
    controller_input_set_stick(&input, HOST_STICK_LEFT, 0xFFFF, 0x1000);
    controller_input_get_state(&input, buttons, sticks);

    // Assert
    ASSERT_EQ(sticks[HOST_STICK_LEFT][0], STICK_MAX);
    ASSERT_EQ(sticks[HOST_STICK_LEFT][1], STICK_MAX);
    return true;
}

static bool test_left_stick_does_not_move_the_joycon_r_stick(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    controller_input_set_stick(&input, HOST_STICK_LEFT, 0, 0);
    controller_input_build_report(&input, out);

    // Assert
    ASSERT_MEM_EQ(&out[5], ((const uint8_t[]){0x13, 0xE8, 0x7A}), 3);
    return true;
}

static bool test_preset_up_pushes_the_vertical_axis_to_the_maximum(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    uint8_t buttons[CONTROLLER_INPUT_BITFIELD_SIZE];
    uint16_t sticks[CONTROLLER_INPUT_STICK_COUNT][2];

    // Act
    bool accepted = controller_input_set_stick_preset(&input, HOST_STICK_RIGHT, HOST_PRESET_UP);
    controller_input_get_state(&input, buttons, sticks);

    // Assert
    ASSERT(accepted);
    ASSERT_EQ(sticks[HOST_STICK_RIGHT][1], STICK_MAX);
    return true;
}

static bool test_center_preset_restores_the_calibrated_center(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);
    uint8_t out[INPUT_REPORT_SIZE];
    controller_input_set_stick_preset(&input, HOST_STICK_RIGHT, HOST_PRESET_DOWN_LEFT);

    // Act
    controller_input_set_stick_preset(&input, HOST_STICK_RIGHT, HOST_PRESET_CENTER);
    controller_input_build_report(&input, out);

    // Assert
    ASSERT_MEM_EQ(&out[5], ((const uint8_t[]){0x13, 0xE8, 0x7A}), 3);
    return true;
}

static bool test_unknown_preset_and_stick_are_rejected(void) {
    // Arrange
    controller_input_t input;
    controller_input_init(&input);

    // Act
    bool bad_preset = controller_input_set_stick_preset(&input, HOST_STICK_RIGHT, 0x09);
    bool bad_stick = controller_input_set_stick(&input, 2, 0, 0);

    // Assert
    ASSERT(!bad_preset);
    ASSERT(!bad_stick);
    return true;
}

TEST_MAIN_BEGIN("controller_input")
    RUN_TEST(test_idle_input_matches_the_captured_idle_report);
    RUN_TEST(test_held_button_bits_map_to_the_report);
    RUN_TEST(test_mask_limits_which_bits_change);
    RUN_TEST(test_buttons_the_joycon_lacks_never_reach_the_report);
    RUN_TEST(test_timed_press_releases_after_its_duration);
    RUN_TEST(test_zero_duration_uses_the_default_press_time);
    RUN_TEST(test_switch_two_only_buttons_can_be_pressed_by_id);
    RUN_TEST(test_unknown_button_id_is_rejected);
    RUN_TEST(test_clear_releases_held_and_pressed_buttons);
    RUN_TEST(test_right_stick_values_are_packed_into_the_report);
    RUN_TEST(test_stick_values_are_clamped_to_twelve_bits);
    RUN_TEST(test_left_stick_does_not_move_the_joycon_r_stick);
    RUN_TEST(test_preset_up_pushes_the_vertical_axis_to_the_maximum);
    RUN_TEST(test_center_preset_restores_the_calibrated_center);
    RUN_TEST(test_unknown_preset_and_stick_are_rejected);
TEST_MAIN_END()
