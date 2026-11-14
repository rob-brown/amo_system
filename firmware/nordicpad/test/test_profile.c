#include "test_framework.h"

#include "controller/profile.h"

#define AD_TYPE_FLAGS 0x01
#define AD_TYPE_MANUFACTURER 0xFF
#define NINTENDO_COMPANY_ID_LOW 0x53
#define NINTENDO_COMPANY_ID_HIGH 0x05

static bool test_advertising_data_is_well_formed_ad_structures(void) {
    // Arrange
    const controller_profile_t *profile = &JOYCON_R_PROFILE;
    size_t offset = 0;

    // Act
    while (offset < profile->advertising_data_length) {
        size_t structure_length = profile->advertising_data[offset];
        offset += 1 + structure_length;
    }

    // Assert
    ASSERT_EQ(offset, profile->advertising_data_length);
    ASSERT(profile->advertising_data_length <= ADVERTISING_DATA_MAX_SIZE);
    return true;
}

static bool test_advertising_data_carries_the_nintendo_manufacturer_id(void) {
    // Arrange
    const controller_profile_t *profile = &JOYCON_R_PROFILE;

    // Act
    const uint8_t *manufacturer = &profile->advertising_data[3];

    // Assert
    ASSERT_EQ(profile->advertising_data[1], AD_TYPE_FLAGS);
    ASSERT_EQ(manufacturer[1], AD_TYPE_MANUFACTURER);
    ASSERT_EQ(manufacturer[2], NINTENDO_COMPANY_ID_LOW);
    ASSERT_EQ(manufacturer[3], NINTENDO_COMPANY_ID_HIGH);
    return true;
}

static bool test_joycon_right_uses_a_seventeen_byte_command_prefix(void) {
    // Arrange / Act
    size_t prefix_size = JOYCON_R_PROFILE.command_prefix_size;

    // Assert
    ASSERT_EQ(prefix_size, 17);
    return true;
}

static bool test_host_address_slot_is_the_empty_field_inside_the_manufacturer_data(void) {
    // Arrange
    const controller_profile_t *profile = &JOYCON_R_PROFILE;
    const uint8_t *slot = &profile->advertising_data[profile->advertising_host_address_offset];
    const uint8_t empty[6] = {0, 0, 0, 0, 0, 0};

    // Act
    uint8_t byte_after_slot = slot[6];

    // Assert
    ASSERT_MEM_EQ(slot, empty, sizeof(empty));
    ASSERT_EQ(byte_after_slot, 0x0F);
    ASSERT(profile->advertising_host_address_offset + 6 <= profile->advertising_data_length);
    return true;
}

TEST_MAIN_BEGIN("profile")
    RUN_TEST(test_host_address_slot_is_the_empty_field_inside_the_manufacturer_data);
    RUN_TEST(test_advertising_data_is_well_formed_ad_structures);
    RUN_TEST(test_advertising_data_carries_the_nintendo_manufacturer_id);
    RUN_TEST(test_joycon_right_uses_a_seventeen_byte_command_prefix);
TEST_MAIN_END()
