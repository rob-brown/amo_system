#include "test_framework.h"

#include "protocol/aes128.h"

static bool test_fips197_appendix_c_vector(void) {
    // Arrange
    const uint8_t key[AES128_KEY_SIZE] = {
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
    };
    const uint8_t plaintext[AES128_BLOCK_SIZE] = {
        0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
        0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF,
    };
    const uint8_t expected[AES128_BLOCK_SIZE] = {
        0x69, 0xC4, 0xE0, 0xD8, 0x6A, 0x7B, 0x04, 0x30,
        0xD8, 0xCD, 0xB7, 0x80, 0x70, 0xB4, 0xC5, 0x5A,
    };
    uint8_t ciphertext[AES128_BLOCK_SIZE];

    // Act
    aes128_encrypt_block(key, plaintext, ciphertext);

    // Assert
    ASSERT_MEM_EQ(ciphertext, expected, AES128_BLOCK_SIZE);
    return true;
}

static bool test_fips197_appendix_b_vector(void) {
    // Arrange
    const uint8_t key[AES128_KEY_SIZE] = {
        0x2B, 0x7E, 0x15, 0x16, 0x28, 0xAE, 0xD2, 0xA6,
        0xAB, 0xF7, 0x15, 0x88, 0x09, 0xCF, 0x4F, 0x3C,
    };
    const uint8_t plaintext[AES128_BLOCK_SIZE] = {
        0x32, 0x43, 0xF6, 0xA8, 0x88, 0x5A, 0x30, 0x8D,
        0x31, 0x31, 0x98, 0xA2, 0xE0, 0x37, 0x07, 0x34,
    };
    const uint8_t expected[AES128_BLOCK_SIZE] = {
        0x39, 0x25, 0x84, 0x1D, 0x02, 0xDC, 0x09, 0xFB,
        0xDC, 0x11, 0x85, 0x97, 0x19, 0x6A, 0x0B, 0x32,
    };
    uint8_t ciphertext[AES128_BLOCK_SIZE];

    // Act
    aes128_encrypt_block(key, plaintext, ciphertext);

    // Assert
    ASSERT_MEM_EQ(ciphertext, expected, AES128_BLOCK_SIZE);
    return true;
}

static bool test_output_may_alias_input(void) {
    // Arrange
    const uint8_t key[AES128_KEY_SIZE] = {0};
    uint8_t aliased[AES128_BLOCK_SIZE] = {0};
    uint8_t separate[AES128_BLOCK_SIZE];
    const uint8_t input[AES128_BLOCK_SIZE] = {0};

    // Act
    aes128_encrypt_block(key, input, separate);
    aes128_encrypt_block(key, aliased, aliased);

    // Assert
    ASSERT_MEM_EQ(aliased, separate, AES128_BLOCK_SIZE);
    return true;
}

TEST_MAIN_BEGIN("aes128")
    RUN_TEST(test_fips197_appendix_c_vector);
    RUN_TEST(test_fips197_appendix_b_vector);
    RUN_TEST(test_output_may_alias_input);
TEST_MAIN_END()
