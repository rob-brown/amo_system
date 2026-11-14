#include "test_framework.h"

#include "protocol/command_frame.h"

#define JOYCON_R_PREFIX_SIZE 17

static bool test_parses_captured_status_request(void) {
    // Arrange
    uint8_t value[JOYCON_R_PREFIX_SIZE + COMMAND_HEADER_SIZE] = {0};
    const uint8_t header[COMMAND_HEADER_SIZE] = {0x07, 0x91, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00};
    memcpy(&value[JOYCON_R_PREFIX_SIZE], header, sizeof(header));
    command_request_t request;

    // Act
    command_frame_status_t status =
        command_frame_parse_request(value, sizeof(value), JOYCON_R_PREFIX_SIZE, &request);

    // Assert
    ASSERT_EQ(status, COMMAND_FRAME_OK);
    ASSERT_EQ(request.command, 0x07);
    ASSERT_EQ(request.subcommand, 0x01);
    ASSERT_EQ(request.transport, COMMAND_TRANSPORT_BLE);
    ASSERT_EQ(request.payload_length, 0);
    return true;
}

static bool test_parses_captured_memory_read_request(void) {
    // Arrange
    const uint8_t value[] = {
        0x02, 0x91, 0x01, 0x04, 0x00, 0x08, 0x00, 0x00,
        0x40, 0x7E, 0x00, 0x00, 0x00, 0x30, 0x01, 0x00,
    };
    const uint8_t expected_payload[] = {0x40, 0x7E, 0x00, 0x00, 0x00, 0x30, 0x01, 0x00};
    command_request_t request;

    // Act
    command_frame_status_t status = command_frame_parse_request(value, sizeof(value), 0, &request);

    // Assert
    ASSERT_EQ(status, COMMAND_FRAME_OK);
    ASSERT_EQ(request.command, 0x02);
    ASSERT_EQ(request.subcommand, 0x04);
    ASSERT_EQ(request.payload_length, sizeof(expected_payload));
    ASSERT_MEM_EQ(request.payload, expected_payload, sizeof(expected_payload));
    return true;
}

static bool test_ignores_bytes_after_the_declared_payload(void) {
    // Arrange
    const uint8_t value[] = {
        0x0A, 0x91, 0x01, 0x02, 0x00, 0x04, 0x00, 0x00,
        0x03, 0x00, 0x00, 0x00, 0xEE, 0xEE,
    };
    command_request_t request;

    // Act
    command_frame_status_t status = command_frame_parse_request(value, sizeof(value), 0, &request);

    // Assert
    ASSERT_EQ(status, COMMAND_FRAME_OK);
    ASSERT_EQ(request.payload_length, 4);
    return true;
}

static bool test_rejects_value_shorter_than_prefix_and_header(void) {
    // Arrange
    const uint8_t value[JOYCON_R_PREFIX_SIZE + COMMAND_HEADER_SIZE - 1] = {0};
    command_request_t request;

    // Act
    command_frame_status_t status =
        command_frame_parse_request(value, sizeof(value), JOYCON_R_PREFIX_SIZE, &request);

    // Assert
    ASSERT_EQ(status, COMMAND_FRAME_TOO_SHORT);
    return true;
}

static bool test_rejects_header_that_is_not_a_request(void) {
    // Arrange
    const uint8_t value[] = {0x07, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00};
    command_request_t request;

    // Act
    command_frame_status_t status = command_frame_parse_request(value, sizeof(value), 0, &request);

    // Assert
    ASSERT_EQ(status, COMMAND_FRAME_NOT_A_REQUEST);
    return true;
}

static bool test_rejects_payload_length_beyond_the_data(void) {
    // Arrange
    const uint8_t value[] = {
        0x15, 0x91, 0x01, 0x04, 0x00, 0x11, 0x00, 0x00,
        0x00, 0x01, 0x02,
    };
    command_request_t request;

    // Act
    command_frame_status_t status = command_frame_parse_request(value, sizeof(value), 0, &request);

    // Assert
    ASSERT_EQ(status, COMMAND_FRAME_LENGTH_EXCEEDS_DATA);
    return true;
}

static bool test_builds_captured_status_reply(void) {
    // Arrange
    const command_request_t request = {
        .command = 0x07, .subcommand = 0x01, .transport = COMMAND_TRANSPORT_BLE,
    };
    const uint8_t payload[] = {0x00};
    const uint8_t expected[] = {0x07, 0x01, 0x01, 0x01, 0x10, 0x78, 0x00, 0x00, 0x00};
    uint8_t output[16];

    // Act
    size_t length = command_frame_build_reply(&request, payload, sizeof(payload), output, sizeof(output));

    // Assert
    ASSERT_EQ(length, sizeof(expected));
    ASSERT_MEM_EQ(output, expected, sizeof(expected));
    return true;
}

static bool test_builds_empty_reply(void) {
    // Arrange
    const command_request_t request = {
        .command = 0x0A, .subcommand = 0x02, .transport = COMMAND_TRANSPORT_BLE,
    };
    const uint8_t expected[] = {0x0A, 0x01, 0x01, 0x02, 0x10, 0x78, 0x00, 0x00};
    uint8_t output[16];

    // Act
    size_t length = command_frame_build_reply(&request, NULL, 0, output, sizeof(output));

    // Assert
    ASSERT_EQ(length, sizeof(expected));
    ASSERT_MEM_EQ(output, expected, sizeof(expected));
    return true;
}

static bool test_reply_reports_zero_when_output_is_too_small(void) {
    // Arrange
    const command_request_t request = {
        .command = 0x07, .subcommand = 0x01, .transport = COMMAND_TRANSPORT_BLE,
    };
    const uint8_t payload[] = {0x00, 0x01};
    uint8_t output[COMMAND_HEADER_SIZE + 1];

    // Act
    size_t length = command_frame_build_reply(&request, payload, sizeof(payload), output, sizeof(output));

    // Assert
    ASSERT_EQ(length, 0);
    return true;
}

TEST_MAIN_BEGIN("command_frame")
    RUN_TEST(test_parses_captured_status_request);
    RUN_TEST(test_parses_captured_memory_read_request);
    RUN_TEST(test_ignores_bytes_after_the_declared_payload);
    RUN_TEST(test_rejects_value_shorter_than_prefix_and_header);
    RUN_TEST(test_rejects_header_that_is_not_a_request);
    RUN_TEST(test_rejects_payload_length_beyond_the_data);
    RUN_TEST(test_builds_captured_status_reply);
    RUN_TEST(test_builds_empty_reply);
    RUN_TEST(test_reply_reports_zero_when_output_is_too_small);
TEST_MAIN_END()
