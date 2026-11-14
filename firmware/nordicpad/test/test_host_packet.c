#include "test_framework.h"

#include "host/crc8.h"
#include "host/host_ids.h"
#include "host/host_packet.h"

static bool test_request_round_trips_through_build_and_parse(void) {
    // Arrange
    const uint8_t payload[] = {0x01, 0x02, 0x03};
    uint8_t packet[HOST_PACKET_MAX_SIZE];
    host_request_t request;

    // Act
    size_t length = host_packet_build_event(0x10, payload, sizeof(payload), packet, sizeof(packet));
    bool parsed = host_packet_parse_request(packet, length, &request);

    // Assert
    ASSERT(parsed);
    ASSERT_EQ(request.command, 0x10);
    ASSERT_EQ(request.payload_length, sizeof(payload));
    ASSERT_MEM_EQ(request.payload, payload, sizeof(payload));
    return true;
}

static bool test_request_without_payload_has_no_payload_pointer(void) {
    // Arrange
    uint8_t packet[HOST_PACKET_MAX_SIZE];
    host_request_t request;

    // Act
    size_t length = host_packet_build_event(0xF0, NULL, 0, packet, sizeof(packet));
    bool parsed = host_packet_parse_request(packet, length, &request);

    // Assert
    ASSERT(parsed);
    ASSERT_EQ(length, 4);
    ASSERT(request.payload == NULL);
    ASSERT_EQ(request.payload_length, 0);
    return true;
}

static bool test_corrupt_checksum_is_rejected(void) {
    // Arrange
    uint8_t packet[HOST_PACKET_MAX_SIZE];
    host_request_t request;
    size_t length = host_packet_build_event(0x10, (const uint8_t[]){0xAA}, 1, packet, sizeof(packet));
    packet[3] ^= 0x01;

    // Act
    bool parsed = host_packet_parse_request(packet, length, &request);

    // Assert
    ASSERT(!parsed);
    return true;
}

static bool test_length_field_must_match_the_data(void) {
    // Arrange
    uint8_t packet[HOST_PACKET_MAX_SIZE];
    host_request_t request;
    size_t length = host_packet_build_event(0x10, (const uint8_t[]){0xAA}, 1, packet, sizeof(packet));

    // Act
    bool parsed = host_packet_parse_request(packet, length - 1, &request);

    // Assert
    ASSERT(!parsed);
    return true;
}

static bool test_response_layout_carries_command_status_and_payload(void) {
    // Arrange
    const uint8_t payload[] = {0xDE, 0xAD};
    uint8_t packet[HOST_PACKET_MAX_SIZE];

    // Act
    size_t length = host_packet_build_response(0x01, HOST_STATUS_BUSY, payload, sizeof(payload), packet, sizeof(packet));

    // Assert
    ASSERT_EQ(length, 7);
    ASSERT_EQ(packet[0], 7);
    ASSERT_EQ(packet[1], 0);
    ASSERT_EQ(packet[2], 0x01);
    ASSERT_EQ(packet[3], HOST_STATUS_BUSY);
    ASSERT_MEM_EQ(&packet[4], payload, sizeof(payload));
    ASSERT_EQ(packet[6], crc8(packet, 6));
    return true;
}

static bool test_build_fails_when_the_buffer_is_too_small(void) {
    // Arrange
    uint8_t packet[4];

    // Act
    size_t length = host_packet_build_response(0x01, 0, (const uint8_t[]){1}, 1, packet, sizeof(packet));

    // Assert
    ASSERT_EQ(length, 0);
    return true;
}

TEST_MAIN_BEGIN("host_packet")
    RUN_TEST(test_request_round_trips_through_build_and_parse);
    RUN_TEST(test_request_without_payload_has_no_payload_pointer);
    RUN_TEST(test_corrupt_checksum_is_rejected);
    RUN_TEST(test_length_field_must_match_the_data);
    RUN_TEST(test_response_layout_carries_command_status_and_payload);
    RUN_TEST(test_build_fails_when_the_buffer_is_too_small);
TEST_MAIN_END()
