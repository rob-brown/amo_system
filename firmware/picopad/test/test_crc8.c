#include "test_framework.h"
#include "../src/crc8.h"

static bool test_empty_data(void) {
    uint8_t data[] = {0};
    uint8_t crc = crc8(data, 0);
    ASSERT_EQ(crc, 0x00);
    return true;
}

static bool test_single_byte_zero(void) {
    uint8_t data[] = {0x00};
    uint8_t crc = crc8(data, 1);
    ASSERT_EQ(crc, 0x00);
    return true;
}

static bool test_single_byte_one(void) {
    uint8_t data[] = {0x01};
    uint8_t crc = crc8(data, 1);
    ASSERT_EQ(crc, 0x07);
    return true;
}

static bool test_single_byte_ff(void) {
    uint8_t data[] = {0xFF};
    uint8_t crc = crc8(data, 1);
    ASSERT(crc != 0x00);
    return true;
}

static bool test_two_bytes(void) {
    uint8_t data[] = {0x01, 0x02};
    uint8_t crc = crc8(data, 2);
    ASSERT(crc != 0x00);
    return true;
}

static bool test_known_pattern_123456789(void) {
    uint8_t data[] = {'1', '2', '3', '4', '5', '6', '7', '8', '9'};
    uint8_t crc = crc8(data, 9);
    ASSERT_EQ(crc, 0xF4);
    return true;
}

static bool test_all_zeros(void) {
    uint8_t data[] = {0x00, 0x00, 0x00, 0x00};
    uint8_t crc = crc8(data, 4);
    ASSERT_EQ(crc, 0x00);
    return true;
}

static bool test_protocol_packet_get_status(void) {
    uint8_t data[] = {0x04, 0x00, 0x01};
    uint8_t crc = crc8(data, 3);
    ASSERT(crc != 0x00);
    return true;
}

static bool test_crc8_update_incremental(void) {
    uint8_t data[] = {0x01, 0x02, 0x03};
    uint8_t crc_full = crc8(data, 3);

    uint8_t crc_inc = CRC8_INIT;
    crc_inc = crc8_update(crc_inc, 0x01);
    crc_inc = crc8_update(crc_inc, 0x02);
    crc_inc = crc8_update(crc_inc, 0x03);

    ASSERT_EQ(crc_full, crc_inc);
    return true;
}

static bool test_different_data_different_crc(void) {
    uint8_t data1[] = {0x01, 0x02, 0x03};
    uint8_t data2[] = {0x01, 0x02, 0x04};

    uint8_t crc1 = crc8(data1, 3);
    uint8_t crc2 = crc8(data2, 3);

    ASSERT(crc1 != crc2);
    return true;
}

static bool test_verify_crc_appended(void) {
    uint8_t packet[] = {0x04, 0x00, 0x01, 0x00};
    uint8_t crc = crc8(packet, 3);
    packet[3] = crc;

    uint8_t verify = crc8(packet, 3);
    ASSERT_EQ(verify, packet[3]);
    return true;
}

static bool test_large_data(void) {
    uint8_t data[256];
    for (int i = 0; i < 256; i++) {
        data[i] = i;
    }

    uint8_t crc1 = crc8(data, 256);
    uint8_t crc2 = crc8(data, 256);
    ASSERT_EQ(crc1, crc2);
    return true;
}

TEST_MAIN_BEGIN("CRC8")
    RUN_TEST(test_empty_data);
    RUN_TEST(test_single_byte_zero);
    RUN_TEST(test_single_byte_one);
    RUN_TEST(test_single_byte_ff);
    RUN_TEST(test_two_bytes);
    RUN_TEST(test_known_pattern_123456789);
    RUN_TEST(test_all_zeros);
    RUN_TEST(test_protocol_packet_get_status);
    RUN_TEST(test_crc8_update_incremental);
    RUN_TEST(test_different_data_different_crc);
    RUN_TEST(test_verify_crc_appended);
    RUN_TEST(test_large_data);
TEST_MAIN_END()
