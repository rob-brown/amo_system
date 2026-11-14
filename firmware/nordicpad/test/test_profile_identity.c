#include "test_framework.h"

#include "controller/profile_identity.h"

static uint8_t base_factory[64];
static uint8_t base_calibration[64];
static uint8_t base_firmware_info[12] = {0x02, 0x01, 0x04, 0x01, 0x0C};

static const memory_region_t BASE_REGIONS[] = {
    {0x00013000, 64, base_factory},
    {0x00013080, 64, base_calibration},
};

static const static_reply_t BASE_REPLIES[] = {
    {0x10, 0x01, base_firmware_info, sizeof(base_firmware_info)},
};

static const controller_identity_t BASE_IDENTITY = {BASE_REGIONS, 2, BASE_REPLIES, 1};

static void prepare_base(void) {
    memset(base_factory, 0x11, sizeof(base_factory));
    for (size_t index = 0; index < sizeof(base_calibration); index++) {
        base_calibration[index] = (uint8_t)index;
    }
}

static bool test_controller_type_replaces_the_firmware_info_type_byte(void) {
    // Arrange
    prepare_base();
    static profile_identity_t identity;

    // Act
    bool built = profile_identity_build(&identity, &BASE_IDENTITY, &PRO_CONTROLLER_PROFILE);

    // Assert
    ASSERT(built);
    const static_reply_t *reply = identity_find_static_reply(&identity.identity, 0x10, 0x01);
    ASSERT(reply != NULL);
    ASSERT_EQ(reply->payload[3], CONTROLLER_TYPE_PRO_CONTROLLER);
    ASSERT_EQ(base_firmware_info[3], 0x01);
    return true;
}

static bool test_dsp_version_and_hardware_variant_come_from_the_profile(void) {
    // Arrange
    prepare_base();
    static profile_identity_t identity;
    uint8_t variant[3];

    // Act
    profile_identity_build(&identity, &BASE_IDENTITY, &PRO_CONTROLLER_PROFILE);
    identity_read_memory(&identity.identity, 0x00013016, sizeof(variant), variant);
    const static_reply_t *info = identity_find_static_reply(&identity.identity, 0x10, 0x01);

    // Assert
    ASSERT_MEM_EQ(variant, ((const uint8_t[]){0x01, 0x06, 0x01}), 3);
    ASSERT_MEM_EQ(&info->payload[8], ((const uint8_t[]){0x00, 0x02, 0x03}), 3);
    return true;
}

static bool test_profile_extra_replies_are_served(void) {
    // Arrange
    prepare_base();
    static profile_identity_t identity;

    // Act
    profile_identity_build(&identity, &BASE_IDENTITY, &PRO_CONTROLLER_PROFILE);
    const static_reply_t *audio = identity_find_static_reply(&identity.identity, 0x18, 0x01);
    const static_reply_t *joycon_audio = NULL;
    static profile_identity_t joycon_identity;
    profile_identity_build(&joycon_identity, &BASE_IDENTITY, &JOYCON_R_PROFILE);
    joycon_audio = identity_find_static_reply(&joycon_identity.identity, 0x18, 0x01);

    // Assert
    ASSERT(audio != NULL);
    ASSERT(joycon_audio == NULL);
    return true;
}

static bool test_product_id_is_written_into_the_factory_data(void) {
    // Arrange
    prepare_base();
    static profile_identity_t identity;
    uint8_t product_id[2];

    // Act
    profile_identity_build(&identity, &BASE_IDENTITY, &PRO_CONTROLLER_PROFILE);
    identity_read_memory(&identity.identity, 0x00013014, 2, product_id);

    // Assert
    ASSERT_MEM_EQ(product_id, ((const uint8_t[]){0x69, 0x20}), 2);
    ASSERT_EQ(base_factory[0x14], 0x11);
    return true;
}

static bool test_profile_serial_digits_replace_the_captured_ones(void) {
    // Arrange
    prepare_base();
    static profile_identity_t identity;
    uint8_t serial[14];

    // Act
    profile_identity_build(&identity, &BASE_IDENTITY, &PRO_CONTROLLER_PROFILE);
    identity_read_memory(&identity.identity, 0x00013002, sizeof(serial), serial);

    // Assert
    ASSERT_MEM_EQ(serial, "HEJ90210000042", sizeof(serial));
    return true;
}

static bool test_profile_without_serial_digits_keeps_the_captured_ones(void) {
    // Arrange
    prepare_base();
    static profile_identity_t identity;
    uint8_t digits[11];

    // Act
    profile_identity_build(&identity, &BASE_IDENTITY, &JOYCON_R_PROFILE);
    identity_read_memory(&identity.identity, 0x00013005, sizeof(digits), digits);

    // Assert
    ASSERT_EQ(digits[0], base_factory[0x05]);
    ASSERT_EQ(digits[10], base_factory[0x0F]);
    return true;
}

static bool test_profile_colors_are_written_in_body_buttons_highlight_grip_order(void) {
    // Arrange
    prepare_base();
    static profile_identity_t identity;
    uint8_t colors[12];

    // Act
    profile_identity_build(&identity, &BASE_IDENTITY, &PRO_CONTROLLER_PROFILE);
    identity_read_memory(&identity.identity, 0x00013019, sizeof(colors), colors);

    // Assert
    ASSERT_MEM_EQ(colors, &PRO_CONTROLLER_PROFILE.colors, sizeof(colors));
    return true;
}

static bool test_colors_can_be_changed_after_the_build(void) {
    // Arrange
    prepare_base();
    static profile_identity_t identity;
    profile_identity_build(&identity, &BASE_IDENTITY, &PRO_CONTROLLER_PROFILE);
    const controller_colors_t red = {{0xFF, 0, 0}, {1, 2, 3}, {4, 5, 6}, {7, 8, 9}};
    uint8_t body[3];

    // Act
    profile_identity_set_colors(&identity, &red);
    identity_read_memory(&identity.identity, 0x00013019, sizeof(body), body);

    // Assert
    ASSERT_MEM_EQ(body, ((const uint8_t[]){0xFF, 0, 0}), 3);
    return true;
}

static bool test_profile_memory_overrides_replace_the_base_blocks(void) {
    // Arrange
    prepare_base();
    static profile_identity_t identity;
    uint8_t secondary[9];
    uint8_t primary[9];

    // Act
    profile_identity_build(&identity, &BASE_IDENTITY, &PRO_CONTROLLER_PROFILE);
    identity_read_memory(&identity.identity, 0x000130E8, sizeof(secondary), secondary);
    identity_read_memory(&identity.identity, 0x000130A8, sizeof(primary), primary);

    // Assert
    ASSERT_MEM_EQ(secondary, ((const uint8_t[]){0x2C, 0x08, 0x84, 0xD1, 0x65, 0x63, 0x2A, 0x26, 0x62}), 9);
    ASSERT_MEM_EQ(primary, ((const uint8_t[]){0xB3, 0x67, 0x83, 0x2E, 0x66, 0x5E, 0x3A, 0x06, 0x5F}), 9);
    return true;
}

static bool test_single_stick_controller_has_no_secondary_stick_calibration(void) {
    // Arrange
    prepare_base();
    static profile_identity_t identity;
    uint8_t secondary[9];

    // Act
    profile_identity_build(&identity, &BASE_IDENTITY, &JOYCON_R_PROFILE);
    identity_read_memory(&identity.identity, 0x000130E8, sizeof(secondary), secondary);

    // Assert
    ASSERT_MEM_EQ(secondary, ((const uint8_t[]){0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF}), 9);
    return true;
}

TEST_MAIN_BEGIN("profile_identity")
    RUN_TEST(test_controller_type_replaces_the_firmware_info_type_byte);
    RUN_TEST(test_dsp_version_and_hardware_variant_come_from_the_profile);
    RUN_TEST(test_profile_extra_replies_are_served);
    RUN_TEST(test_product_id_is_written_into_the_factory_data);
    RUN_TEST(test_profile_serial_digits_replace_the_captured_ones);
    RUN_TEST(test_profile_without_serial_digits_keeps_the_captured_ones);
    RUN_TEST(test_profile_colors_are_written_in_body_buttons_highlight_grip_order);
    RUN_TEST(test_colors_can_be_changed_after_the_build);
    RUN_TEST(test_profile_memory_overrides_replace_the_base_blocks);
    RUN_TEST(test_single_stick_controller_has_no_secondary_stick_calibration);
TEST_MAIN_END()
