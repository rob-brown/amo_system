#include "test_framework.h"

#include <string.h>

#include "storage/pairing_record_codec.h"

static pairing_record_t sample_record(void) {
    pairing_record_t record;
    for (int index = 0; index < PAIRING_RECORD_KEY_SIZE; index++) {
        record.link_key[index] = (uint8_t)(0xA0 + index);
    }
    for (int index = 0; index < PAIRING_RECORD_ADDRESS_SIZE; index++) {
        record.host_address[index] = (uint8_t)(0x10 + index);
    }
    return record;
}

static bool test_encoded_record_decodes_to_the_same_key(void) {
    // Arrange
    const pairing_record_t original = sample_record();
    uint8_t image[PAIRING_IMAGE_SIZE];
    pairing_record_t decoded;

    // Act
    pairing_record_encode(&original, image);
    bool valid = pairing_record_decode(image, &decoded);

    // Assert
    ASSERT(valid);
    ASSERT_MEM_EQ(decoded.link_key, original.link_key, PAIRING_RECORD_KEY_SIZE);
    return true;
}

static bool test_erased_flash_is_not_a_record(void) {
    // Arrange
    uint8_t image[PAIRING_IMAGE_SIZE];
    memset(image, 0xFF, sizeof(image));
    pairing_record_t decoded;

    // Act
    bool valid = pairing_record_decode(image, &decoded);

    // Assert
    ASSERT(!valid);
    return true;
}

static bool test_corrupted_key_is_rejected(void) {
    // Arrange
    const pairing_record_t original = sample_record();
    uint8_t image[PAIRING_IMAGE_SIZE];
    pairing_record_t decoded;
    pairing_record_encode(&original, image);
    image[8] ^= 0x01;

    // Act
    bool valid = pairing_record_decode(image, &decoded);

    // Assert
    ASSERT(!valid);
    return true;
}

static bool test_encoded_record_keeps_the_host_address(void) {
    // Arrange
    const pairing_record_t original = sample_record();
    uint8_t image[PAIRING_IMAGE_SIZE];
    pairing_record_t decoded;

    // Act
    pairing_record_encode(&original, image);
    bool valid = pairing_record_decode(image, &decoded);

    // Assert
    ASSERT(valid);
    ASSERT_MEM_EQ(decoded.host_address, original.host_address, PAIRING_RECORD_ADDRESS_SIZE);
    return true;
}

static bool test_corrupted_host_address_is_rejected(void) {
    // Arrange
    const pairing_record_t original = sample_record();
    uint8_t image[PAIRING_IMAGE_SIZE];
    pairing_record_t decoded;
    pairing_record_encode(&original, image);
    image[4 + PAIRING_RECORD_KEY_SIZE] ^= 0x01;

    // Act
    bool valid = pairing_record_decode(image, &decoded);

    // Assert
    ASSERT(!valid);
    return true;
}

TEST_MAIN_BEGIN("pairing_record_codec")
    RUN_TEST(test_encoded_record_keeps_the_host_address);
    RUN_TEST(test_corrupted_host_address_is_rejected);
    RUN_TEST(test_encoded_record_decodes_to_the_same_key);
    RUN_TEST(test_erased_flash_is_not_a_record);
    RUN_TEST(test_corrupted_key_is_rejected);
TEST_MAIN_END()
