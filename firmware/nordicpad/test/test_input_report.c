#include "test_framework.h"

#include "controller/input_report.h"

static bool test_idle_report_has_the_captured_header(void) {
    // Arrange
    input_report_t report;
    input_report_init(&report);
    uint8_t out[INPUT_REPORT_SIZE];
    const uint8_t header[] = {0x18, 0x00, 0x00, 0x07, 0x13, 0xE8, 0x7A, 0x38};

    // Act
    input_report_build(&report, out);

    // Assert
    ASSERT_MEM_EQ(&out[1], header, sizeof(header));
    return true;
}

static bool test_counter_increases_with_every_report(void) {
    // Arrange
    input_report_t report;
    input_report_init(&report);
    uint8_t first[INPUT_REPORT_SIZE];
    uint8_t second[INPUT_REPORT_SIZE];

    // Act
    input_report_build(&report, first);
    input_report_build(&report, second);

    // Assert
    ASSERT_EQ(first[0], 0);
    ASSERT_EQ(second[0], 1);
    return true;
}

static bool test_counter_wraps_after_255(void) {
    // Arrange
    input_report_t report;
    input_report_init(&report);
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    for (int round = 0; round < 257; round++) {
        input_report_build(&report, out);
    }

    // Assert
    ASSERT_EQ(out[0], 0);
    return true;
}

static bool test_buttons_land_in_bytes_two_and_three(void) {
    // Arrange
    input_report_t report;
    input_report_init(&report);
    report.buttons = BUTTON_A | BUTTON_ZR | BUTTON_HOME | BUTTON_SL;
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    input_report_build(&report, out);

    // Assert
    ASSERT_EQ(out[2], 0x22);
    ASSERT_EQ(out[3], 0x81);
    return true;
}

static bool test_stick_is_packed_as_two_twelve_bit_values(void) {
    // Arrange
    input_report_t report;
    input_report_init(&report);
    report.stick_x = 0xABC;
    report.stick_y = 0x123;
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    input_report_build(&report, out);

    // Assert
    ASSERT_EQ(out[5], 0xBC);
    ASSERT_EQ(out[6], 0x3A);
    ASSERT_EQ(out[7], 0x12);
    return true;
}

static bool test_nfc_counter_lands_in_byte_fourteen(void) {
    // Arrange
    input_report_t report;
    input_report_init(&report);
    report.nfc_counter = 5;
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    input_report_build(&report, out);

    // Assert
    ASSERT_EQ(out[14], 5);
    return true;
}

static bool test_pro_controller_buttons_use_three_bytes(void) {
    // Arrange
    input_report_t report;
    input_report_init(&report);
    report.layout = &INPUT_LAYOUT_PRO_CONTROLLER;
    report.buttons = BUTTON_A | BUTTON_ZL | BUTTON_DOWN | BUTTON_CAPTURE | BUTTON_LEFT_STICK;
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    input_report_build(&report, out);

    // Assert
    ASSERT_EQ(out[2], 0x02);
    ASSERT_EQ(out[3], 0xA1);
    ASSERT_EQ(out[4], 0x02);
    return true;
}

static bool test_pro_controller_has_two_sticks(void) {
    // Arrange
    input_report_t report;
    input_report_init(&report);
    report.layout = &INPUT_LAYOUT_PRO_CONTROLLER;
    report.left_x = 0x123;
    report.left_y = 0x456;
    report.stick_x = 0xABC;
    report.stick_y = 0xDEF;
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    input_report_build(&report, out);

    // Assert
    ASSERT_MEM_EQ(&out[5], ((const uint8_t[]){0x23, 0x61, 0x45}), 3);
    ASSERT_MEM_EQ(&out[8], ((const uint8_t[]){0xBC, 0xFA, 0xDE}), 3);
    return true;
}

static bool test_pro_controller_nfc_counter_lands_in_byte_twelve(void) {
    // Arrange
    input_report_t report;
    input_report_init(&report);
    report.layout = &INPUT_LAYOUT_PRO_CONTROLLER;
    report.nfc_counter = 6;
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    input_report_build(&report, out);

    // Assert
    ASSERT_EQ(out[12], 6);
    return true;
}

static bool test_pro_controller_reports_a_zeroed_motion_block(void) {
    // Arrange
    input_report_t report;
    input_report_init(&report);
    report.layout = &INPUT_LAYOUT_PRO_CONTROLLER;
    uint8_t out[INPUT_REPORT_SIZE];
    uint8_t zeros[40] = {0};

    // Act
    input_report_build(&report, out);

    // Assert
    ASSERT_EQ(out[14], 0x28);
    ASSERT_MEM_EQ(&out[15], zeros, sizeof(zeros));
    return true;
}

static bool test_pro_controller_grip_buttons_land_in_byte_four(void) {
    // Arrange
    input_report_t report;
    input_report_init(&report);
    report.layout = &INPUT_LAYOUT_PRO_CONTROLLER;
    report.buttons = BUTTON_GL | BUTTON_GR;
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    input_report_build(&report, out);

    // Assert
    ASSERT_EQ(out[4], 0x0C);
    return true;
}

static bool test_joycon_ignores_the_buttons_it_lacks(void) {
    // Arrange
    input_report_t report;
    input_report_init(&report);
    report.buttons = BUTTON_L | BUTTON_ZL | BUTTON_UP | BUTTON_MINUS | BUTTON_CAPTURE;
    uint8_t out[INPUT_REPORT_SIZE];

    // Act
    input_report_build(&report, out);

    // Assert
    ASSERT_EQ(out[2], 0x00);
    ASSERT_EQ(out[3], 0x00);
    return true;
}

TEST_MAIN_BEGIN("input_report")
    RUN_TEST(test_pro_controller_buttons_use_three_bytes);
    RUN_TEST(test_pro_controller_has_two_sticks);
    RUN_TEST(test_pro_controller_nfc_counter_lands_in_byte_twelve);
    RUN_TEST(test_pro_controller_reports_a_zeroed_motion_block);
    RUN_TEST(test_pro_controller_grip_buttons_land_in_byte_four);
    RUN_TEST(test_joycon_ignores_the_buttons_it_lacks);
    RUN_TEST(test_nfc_counter_lands_in_byte_fourteen);
    RUN_TEST(test_buttons_land_in_bytes_two_and_three);
    RUN_TEST(test_stick_is_packed_as_two_twelve_bit_values);
    RUN_TEST(test_idle_report_has_the_captured_header);
    RUN_TEST(test_counter_increases_with_every_report);
    RUN_TEST(test_counter_wraps_after_255);
TEST_MAIN_END()
