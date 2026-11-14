#include "test_framework.h"

#include "host/cobs.h"
#include "host/host_ids.h"
#include "host/host_link.h"

typedef struct {
    int requests;
    uint8_t command;
    uint8_t payload[16];
    size_t payload_length;
    uint8_t written[HOST_LINK_FRAME_SIZE];
    size_t written_length;
} capture_t;

static capture_t capture;
static host_link_t link_under_test;

static void on_request(void *context, const host_request_t *request) {
    capture_t *target = context;
    target->requests++;
    target->command = request->command;
    target->payload_length = request->payload_length;
    if (request->payload_length > 0) {
        memcpy(target->payload, request->payload, request->payload_length);
    }
}

static void on_write(void *context, const uint8_t *data, size_t length) {
    capture_t *target = context;
    memcpy(target->written, data, length);
    target->written_length = length;
}

static void reset_link(void) {
    memset(&capture, 0, sizeof(capture));
    const host_link_config_t config = {on_request, on_write, &capture};
    host_link_init(&link_under_test, &config);
}

static size_t encode_request(uint8_t command, const uint8_t *payload, size_t payload_length, uint8_t *out) {
    uint8_t packet[HOST_PACKET_MAX_SIZE];
    size_t length = host_packet_build_event(command, payload, payload_length, packet, sizeof(packet));
    size_t encoded = cobs_encode(packet, length, out, HOST_LINK_FRAME_SIZE);
    out[encoded] = COBS_DELIMITER;
    return encoded + 1;
}

static bool test_request_split_across_reads_is_delivered_once(void) {
    // Arrange
    reset_link();
    uint8_t wire[64];
    size_t length = encode_request(HOST_CMD_PING, (const uint8_t[]){0x11, 0x00, 0x22}, 3, wire);

    // Act
    host_link_receive(&link_under_test, wire, 3);
    host_link_receive(&link_under_test, &wire[3], length - 3);

    // Assert
    ASSERT_EQ(capture.requests, 1);
    ASSERT_EQ(capture.command, HOST_CMD_PING);
    ASSERT_EQ(capture.payload_length, 3);
    ASSERT_EQ(capture.payload[1], 0x00);
    return true;
}

static bool test_damaged_frame_is_dropped_and_the_next_one_still_works(void) {
    // Arrange
    reset_link();
    uint8_t bad[64];
    uint8_t good[64];
    size_t bad_length = encode_request(HOST_CMD_PING, (const uint8_t[]){0x01}, 1, bad);
    size_t good_length = encode_request(HOST_CMD_GET_STATUS, NULL, 0, good);
    bad[1] ^= 0x01;

    // Act
    host_link_receive(&link_under_test, bad, bad_length);
    host_link_receive(&link_under_test, good, good_length);

    // Assert
    ASSERT_EQ(capture.requests, 1);
    ASSERT_EQ(capture.command, HOST_CMD_GET_STATUS);
    return true;
}

static bool test_empty_frames_are_ignored(void) {
    // Arrange
    reset_link();
    const uint8_t delimiters[] = {0x00, 0x00, 0x00};

    // Act
    host_link_receive(&link_under_test, delimiters, sizeof(delimiters));

    // Assert
    ASSERT_EQ(capture.requests, 0);
    return true;
}

static bool test_oversized_frame_is_dropped_without_overflowing(void) {
    // Arrange
    reset_link();
    uint8_t filler[HOST_LINK_FRAME_SIZE + 100];
    memset(filler, 0x55, sizeof(filler));
    uint8_t good[64];
    size_t good_length = encode_request(HOST_CMD_PING, NULL, 0, good);

    // Act
    host_link_receive(&link_under_test, filler, sizeof(filler));
    host_link_receive(&link_under_test, (const uint8_t[]){COBS_DELIMITER}, 1);
    host_link_receive(&link_under_test, good, good_length);

    // Assert
    ASSERT_EQ(capture.requests, 1);
    return true;
}

static bool test_response_is_written_as_one_delimited_cobs_frame(void) {
    // Arrange
    reset_link();
    uint8_t decoded[HOST_PACKET_MAX_SIZE];

    // Act
    bool sent = host_link_send_response(&link_under_test, HOST_CMD_PING, HOST_STATUS_OK, (const uint8_t[]){0xAB}, 1);
    size_t decoded_length = cobs_decode(capture.written, capture.written_length - 1, decoded, sizeof(decoded));

    // Assert
    ASSERT(sent);
    ASSERT_EQ(capture.written[capture.written_length - 1], COBS_DELIMITER);
    ASSERT_EQ(decoded_length, 6);
    ASSERT_EQ(decoded[2], HOST_CMD_PING);
    ASSERT_EQ(decoded[3], HOST_STATUS_OK);
    ASSERT_EQ(decoded[4], 0xAB);
    return true;
}

static bool test_event_is_written_without_a_status_byte(void) {
    // Arrange
    reset_link();
    uint8_t decoded[HOST_PACKET_MAX_SIZE];

    // Act
    host_link_send_event(&link_under_test, HOST_EVT_CONNECTION_CHANGED, (const uint8_t[]){0x03}, 1);
    size_t decoded_length = cobs_decode(capture.written, capture.written_length - 1, decoded, sizeof(decoded));

    // Assert
    ASSERT_EQ(decoded_length, 5);
    ASSERT_EQ(decoded[2], HOST_EVT_CONNECTION_CHANGED);
    ASSERT_EQ(decoded[3], 0x03);
    return true;
}

TEST_MAIN_BEGIN("host_link")
    RUN_TEST(test_request_split_across_reads_is_delivered_once);
    RUN_TEST(test_damaged_frame_is_dropped_and_the_next_one_still_works);
    RUN_TEST(test_empty_frames_are_ignored);
    RUN_TEST(test_oversized_frame_is_dropped_without_overflowing);
    RUN_TEST(test_response_is_written_as_one_delimited_cobs_frame);
    RUN_TEST(test_event_is_written_without_a_status_byte);
TEST_MAIN_END()
