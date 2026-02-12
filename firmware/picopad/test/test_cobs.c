#include "test_framework.h"
#include "../src/cobs.h"

static bool test_encode_no_zeros(void) {
    uint8_t input[] = {0x01, 0x02, 0x03, 0x04};
    uint8_t output[10];
    uint8_t expected[] = {0x05, 0x01, 0x02, 0x03, 0x04};

    size_t len = cobs_encode(input, 4, output, sizeof(output));
    ASSERT_EQ(len, 5);
    ASSERT_MEM_EQ(output, expected, 5);
    return true;
}

static bool test_encode_single_zero(void) {
    uint8_t input[] = {0x00};
    uint8_t output[10];
    uint8_t expected[] = {0x01, 0x01};

    size_t len = cobs_encode(input, 1, output, sizeof(output));
    ASSERT_EQ(len, 2);
    ASSERT_MEM_EQ(output, expected, 2);
    return true;
}

static bool test_encode_zero_at_start(void) {
    uint8_t input[] = {0x00, 0x01, 0x02};
    uint8_t output[10];
    uint8_t expected[] = {0x01, 0x03, 0x01, 0x02};

    size_t len = cobs_encode(input, 3, output, sizeof(output));
    ASSERT_EQ(len, 4);
    ASSERT_MEM_EQ(output, expected, 4);
    return true;
}

static bool test_encode_zero_at_end(void) {
    uint8_t input[] = {0x01, 0x02, 0x00};
    uint8_t output[10];
    uint8_t expected[] = {0x03, 0x01, 0x02, 0x01};

    size_t len = cobs_encode(input, 3, output, sizeof(output));
    ASSERT_EQ(len, 4);
    ASSERT_MEM_EQ(output, expected, 4);
    return true;
}

static bool test_encode_multiple_zeros(void) {
    uint8_t input[] = {0x00, 0x00};
    uint8_t output[10];
    uint8_t expected[] = {0x01, 0x01, 0x01};

    size_t len = cobs_encode(input, 2, output, sizeof(output));
    ASSERT_EQ(len, 3);
    ASSERT_MEM_EQ(output, expected, 3);
    return true;
}

static bool test_encode_mixed(void) {
    uint8_t input[] = {0x01, 0x00, 0x02, 0x03, 0x00, 0x04};
    uint8_t output[10];
    uint8_t expected[] = {0x02, 0x01, 0x03, 0x02, 0x03, 0x02, 0x04};

    size_t len = cobs_encode(input, 6, output, sizeof(output));
    ASSERT_EQ(len, 7);
    ASSERT_MEM_EQ(output, expected, 7);
    return true;
}

static bool test_decode_no_zeros(void) {
    uint8_t input[] = {0x05, 0x01, 0x02, 0x03, 0x04};
    uint8_t output[10];
    uint8_t expected[] = {0x01, 0x02, 0x03, 0x04};

    size_t len = cobs_decode(input, 5, output, sizeof(output));
    ASSERT_EQ(len, 4);
    ASSERT_MEM_EQ(output, expected, 4);
    return true;
}

static bool test_decode_single_zero(void) {
    uint8_t input[] = {0x01, 0x01};
    uint8_t output[10];
    uint8_t expected[] = {0x00};

    size_t len = cobs_decode(input, 2, output, sizeof(output));
    ASSERT_EQ(len, 1);
    ASSERT_MEM_EQ(output, expected, 1);
    return true;
}

static bool test_decode_zero_at_start(void) {
    uint8_t input[] = {0x01, 0x03, 0x01, 0x02};
    uint8_t output[10];
    uint8_t expected[] = {0x00, 0x01, 0x02};

    size_t len = cobs_decode(input, 4, output, sizeof(output));
    ASSERT_EQ(len, 3);
    ASSERT_MEM_EQ(output, expected, 3);
    return true;
}

static bool test_decode_zero_at_end(void) {
    uint8_t input[] = {0x03, 0x01, 0x02, 0x01};
    uint8_t output[10];
    uint8_t expected[] = {0x01, 0x02, 0x00};

    size_t len = cobs_decode(input, 4, output, sizeof(output));
    ASSERT_EQ(len, 3);
    ASSERT_MEM_EQ(output, expected, 3);
    return true;
}

static bool test_roundtrip_simple(void) {
    uint8_t original[] = {0x01, 0x02, 0x03, 0x04, 0x05};
    uint8_t encoded[10];
    uint8_t decoded[10];

    size_t enc_len = cobs_encode(original, 5, encoded, sizeof(encoded));
    ASSERT(enc_len > 0);

    size_t dec_len = cobs_decode(encoded, enc_len, decoded, sizeof(decoded));
    ASSERT_EQ(dec_len, 5);
    ASSERT_MEM_EQ(decoded, original, 5);
    return true;
}

static bool test_roundtrip_with_zeros(void) {
    uint8_t original[] = {0x00, 0x01, 0x00, 0x02, 0x00};
    uint8_t encoded[10];
    uint8_t decoded[10];

    size_t enc_len = cobs_encode(original, 5, encoded, sizeof(encoded));
    ASSERT(enc_len > 0);

    size_t dec_len = cobs_decode(encoded, enc_len, decoded, sizeof(decoded));
    ASSERT_EQ(dec_len, 5);
    ASSERT_MEM_EQ(decoded, original, 5);
    return true;
}

static bool test_roundtrip_all_zeros(void) {
    uint8_t original[] = {0x00, 0x00, 0x00, 0x00};
    uint8_t encoded[10];
    uint8_t decoded[10];

    size_t enc_len = cobs_encode(original, 4, encoded, sizeof(encoded));
    ASSERT(enc_len > 0);

    size_t dec_len = cobs_decode(encoded, enc_len, decoded, sizeof(decoded));
    ASSERT_EQ(dec_len, 4);
    ASSERT_MEM_EQ(decoded, original, 4);
    return true;
}

static bool test_roundtrip_protocol_packet(void) {
    uint8_t original[] = {0x04, 0x00, 0x01, 0x05};
    uint8_t encoded[10];
    uint8_t decoded[10];

    size_t enc_len = cobs_encode(original, 4, encoded, sizeof(encoded));
    ASSERT(enc_len > 0);

    size_t dec_len = cobs_decode(encoded, enc_len, decoded, sizeof(decoded));
    ASSERT_EQ(dec_len, 4);
    ASSERT_MEM_EQ(decoded, original, 4);
    return true;
}

static bool test_decode_invalid_zero_code(void) {
    uint8_t input[] = {0x00, 0x01, 0x02};
    uint8_t output[10];

    size_t len = cobs_decode(input, 3, output, sizeof(output));
    ASSERT_EQ(len, 0);
    return true;
}

static bool test_encode_null_input(void) {
    uint8_t output[10];
    size_t len = cobs_encode(NULL, 5, output, sizeof(output));
    ASSERT_EQ(len, 0);
    return true;
}

static bool test_encode_null_output(void) {
    uint8_t input[] = {0x01, 0x02};
    size_t len = cobs_encode(input, 2, NULL, 10);
    ASSERT_EQ(len, 0);
    return true;
}

static bool test_encode_zero_length(void) {
    uint8_t input[] = {0x01};
    uint8_t output[10];
    size_t len = cobs_encode(input, 0, output, sizeof(output));
    ASSERT_EQ(len, 0);
    return true;
}

static bool test_roundtrip_254_bytes_no_zeros(void) {
    uint8_t original[254];
    uint8_t encoded[260];
    uint8_t decoded[260];

    for (int i = 0; i < 254; i++) {
        original[i] = (i % 255) + 1;
    }

    size_t enc_len = cobs_encode(original, 254, encoded, sizeof(encoded));
    ASSERT(enc_len > 0);

    size_t dec_len = cobs_decode(encoded, enc_len, decoded, sizeof(decoded));
    ASSERT_EQ(dec_len, 254);
    ASSERT_MEM_EQ(decoded, original, 254);
    return true;
}

static bool test_roundtrip_255_bytes_with_zeros(void) {
    uint8_t original[255];
    uint8_t encoded[260];
    uint8_t decoded[260];

    for (int i = 0; i < 255; i++) {
        original[i] = i % 10 == 0 ? 0 : i;
    }

    size_t enc_len = cobs_encode(original, 255, encoded, sizeof(encoded));
    ASSERT(enc_len > 0);

    size_t dec_len = cobs_decode(encoded, enc_len, decoded, sizeof(decoded));
    ASSERT_EQ(dec_len, 255);
    ASSERT_MEM_EQ(decoded, original, 255);
    return true;
}

static bool test_encoded_size_max(void) {
    ASSERT(cobs_encoded_size_max(1) >= 2);
    ASSERT(cobs_encoded_size_max(254) >= 255);
    ASSERT(cobs_encoded_size_max(255) >= 257);
    ASSERT(cobs_encoded_size_max(508) >= 510);
    return true;
}

TEST_MAIN_BEGIN("COBS")
    RUN_TEST(test_encode_no_zeros);
    RUN_TEST(test_encode_single_zero);
    RUN_TEST(test_encode_zero_at_start);
    RUN_TEST(test_encode_zero_at_end);
    RUN_TEST(test_encode_multiple_zeros);
    RUN_TEST(test_encode_mixed);
    RUN_TEST(test_decode_no_zeros);
    RUN_TEST(test_decode_single_zero);
    RUN_TEST(test_decode_zero_at_start);
    RUN_TEST(test_decode_zero_at_end);
    RUN_TEST(test_roundtrip_simple);
    RUN_TEST(test_roundtrip_with_zeros);
    RUN_TEST(test_roundtrip_all_zeros);
    RUN_TEST(test_roundtrip_protocol_packet);
    RUN_TEST(test_decode_invalid_zero_code);
    RUN_TEST(test_encode_null_input);
    RUN_TEST(test_encode_null_output);
    RUN_TEST(test_encode_zero_length);
    RUN_TEST(test_roundtrip_254_bytes_no_zeros);
    RUN_TEST(test_roundtrip_255_bytes_with_zeros);
    RUN_TEST(test_encoded_size_max);
TEST_MAIN_END()
