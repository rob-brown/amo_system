#include "test_framework.h"
#include "../src/cobs.h"
#include "../src/crc8.h"
#include "../src/host_protocol.h"

static uint8_t g_sent_data[4096];
static size_t g_sent_len = 0;
static bool g_advertising_started = false;
static bool g_advertising_stopped = false;
static bool g_disconnected = false;
static host_led_mode_t g_led_mode = HOST_LED_AUTO;
static bool g_reset_called = false;
static bool g_reset_bootloader = false;

static void mock_send(const uint8_t *data, size_t len) {
    memcpy(g_sent_data + g_sent_len, data, len);
    g_sent_len += len;
}

static void mock_start_advertising(void) {
    g_advertising_started = true;
}

static void mock_stop_advertising(void) {
    g_advertising_stopped = true;
}

static void mock_disconnect(void) {
    g_disconnected = true;
}

static void mock_set_led(host_led_mode_t mode) {
    g_led_mode = mode;
}

static void mock_reset(bool bootloader) {
    g_reset_called = true;
    g_reset_bootloader = bootloader;
}

static void reset_mocks(void) {
    g_sent_len = 0;
    memset(g_sent_data, 0, sizeof(g_sent_data));
    g_advertising_started = false;
    g_advertising_stopped = false;
    g_disconnected = false;
    g_led_mode = HOST_LED_AUTO;
    g_reset_called = false;
    g_reset_bootloader = false;
}

static size_t decode_response(uint8_t *decoded, size_t decoded_size, size_t *decoded_len) {
    if (g_sent_len == 0) return 0;

    size_t delim_pos = 0;
    for (size_t i = 0; i < g_sent_len; i++) {
        if (g_sent_data[i] == COBS_DELIMITER) {
            delim_pos = i;
            break;
        }
    }

    if (delim_pos == 0) return 0;

    *decoded_len = cobs_decode(g_sent_data, delim_pos, decoded, decoded_size);
    return delim_pos + 1;
}

static bool test_build_packet_simple(void) {
    uint8_t output[64];
    size_t len = host_protocol_build_packet(HOST_CMD_GET_STATUS, NULL, 0, output, sizeof(output));

    ASSERT_EQ(len, 4);
    ASSERT_EQ(output[0], 0x04);
    ASSERT_EQ(output[1], 0x00);
    ASSERT_EQ(output[2], HOST_CMD_GET_STATUS);

    uint8_t expected_crc = crc8(output, 3);
    ASSERT_EQ(output[3], expected_crc);
    return true;
}

static bool test_build_packet_with_payload(void) {
    uint8_t payload[] = {0x01, 0x02, 0x03};
    uint8_t output[64];
    size_t len = host_protocol_build_packet(HOST_CMD_SET_CONTROLLER_TYPE, payload, 3, output, sizeof(output));

    ASSERT_EQ(len, 7);
    ASSERT_EQ(output[0], 0x07);
    ASSERT_EQ(output[1], 0x00);
    ASSERT_EQ(output[2], HOST_CMD_SET_CONTROLLER_TYPE);
    ASSERT_MEM_EQ(output + 3, payload, 3);

    uint8_t expected_crc = crc8(output, 6);
    ASSERT_EQ(output[6], expected_crc);
    return true;
}

static bool test_build_response_ok(void) {
    uint8_t output[64];
    size_t len = host_protocol_build_response(HOST_CMD_PING, HOST_STATUS_OK, NULL, 0, output, sizeof(output));

    ASSERT_EQ(len, 5);
    ASSERT_EQ(output[0], 0x05);
    ASSERT_EQ(output[1], 0x00);
    ASSERT_EQ(output[2], HOST_CMD_PING);
    ASSERT_EQ(output[3], HOST_STATUS_OK);

    uint8_t expected_crc = crc8(output, 4);
    ASSERT_EQ(output[4], expected_crc);
    return true;
}

static bool test_build_response_with_payload(void) {
    uint8_t payload[] = {0xAA, 0xBB};
    uint8_t output[64];
    size_t len = host_protocol_build_response(HOST_CMD_PING, HOST_STATUS_OK, payload, 2, output, sizeof(output));

    ASSERT_EQ(len, 7);
    ASSERT_EQ(output[0], 0x07);
    ASSERT_EQ(output[1], 0x00);
    ASSERT_EQ(output[2], HOST_CMD_PING);
    ASSERT_EQ(output[3], HOST_STATUS_OK);
    ASSERT_MEM_EQ(output + 4, payload, 2);
    return true;
}

static bool test_parse_packet_valid(void) {
    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(HOST_CMD_GET_STATUS, NULL, 0, packet, sizeof(packet));

    uint8_t cmd;
    uint8_t *payload;
    size_t payload_len;

    bool result = host_protocol_parse_packet(packet, pkt_len, &cmd, &payload, &payload_len);

    ASSERT(result);
    ASSERT_EQ(cmd, HOST_CMD_GET_STATUS);
    ASSERT_EQ(payload_len, 0);
    return true;
}

static bool test_parse_packet_with_payload(void) {
    uint8_t orig_payload[] = {0x01, 0x02, 0x03};
    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(HOST_CMD_SET_ALL_BUTTONS, orig_payload, 3, packet, sizeof(packet));

    uint8_t cmd;
    uint8_t *payload;
    size_t payload_len;

    bool result = host_protocol_parse_packet(packet, pkt_len, &cmd, &payload, &payload_len);

    ASSERT(result);
    ASSERT_EQ(cmd, HOST_CMD_SET_ALL_BUTTONS);
    ASSERT_EQ(payload_len, 3);
    ASSERT_MEM_EQ(payload, orig_payload, 3);
    return true;
}

static bool test_parse_packet_bad_length(void) {
    uint8_t packet[] = {0x10, 0x00, 0x01, 0x00};

    uint8_t cmd;
    uint8_t *payload;
    size_t payload_len;

    bool result = host_protocol_parse_packet(packet, 4, &cmd, &payload, &payload_len);
    ASSERT(!result);
    return true;
}

static bool test_parse_packet_bad_crc(void) {
    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(HOST_CMD_GET_STATUS, NULL, 0, packet, sizeof(packet));
    packet[pkt_len - 1] ^= 0xFF;

    uint8_t cmd;
    uint8_t *payload;
    size_t payload_len;

    bool result = host_protocol_parse_packet(packet, pkt_len, &cmd, &payload, &payload_len);
    ASSERT(!result);
    return true;
}

static bool test_parse_response_valid(void) {
    uint8_t resp_payload[] = {0x11, 0x22};
    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_response(HOST_CMD_PING, HOST_STATUS_OK, resp_payload, 2, packet, sizeof(packet));

    uint8_t cmd;
    host_status_t status;
    uint8_t *payload;
    size_t payload_len;

    bool result = host_protocol_parse_response(packet, pkt_len, &cmd, &status, &payload, &payload_len);

    ASSERT(result);
    ASSERT_EQ(cmd, HOST_CMD_PING);
    ASSERT_EQ(status, HOST_STATUS_OK);
    ASSERT_EQ(payload_len, 2);
    ASSERT_MEM_EQ(payload, resp_payload, 2);
    return true;
}

static bool test_protocol_init(void) {
    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);

    host_protocol_init(&proto, &controller);

    ASSERT_EQ(proto.conn_state, HOST_CONN_DISCONNECTED);
    ASSERT_EQ(proto.player_number, 0xFF);
    ASSERT_EQ(proto.amiibo_state, HOST_AMIIBO_NONE);
    return true;
}

static bool test_handle_ping_empty(void) {
    reset_mocks();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, mock_start_advertising, mock_stop_advertising,
                                 mock_disconnect, mock_set_led, mock_reset, mock_send);

    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(HOST_CMD_PING, NULL, 0, packet, sizeof(packet));

    uint8_t encoded[128];
    size_t enc_len = cobs_encode(packet, pkt_len, encoded, sizeof(encoded));
    encoded[enc_len++] = COBS_DELIMITER;

    host_protocol_rx_bytes(&proto, encoded, enc_len);

    ASSERT(g_sent_len > 0);

    uint8_t decoded[64];
    size_t decoded_len;
    decode_response(decoded, sizeof(decoded), &decoded_len);

    uint8_t cmd;
    host_status_t status;
    uint8_t *payload;
    size_t payload_len;

    bool result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);
    ASSERT(result);
    ASSERT_EQ(cmd, HOST_CMD_PING);
    ASSERT_EQ(status, HOST_STATUS_OK);
    ASSERT_EQ(payload_len, 0);
    return true;
}

static bool test_handle_ping_echo(void) {
    reset_mocks();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, mock_start_advertising, mock_stop_advertising,
                                 mock_disconnect, mock_set_led, mock_reset, mock_send);

    uint8_t ping_data[] = {0xDE, 0xAD, 0xBE, 0xEF};
    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(HOST_CMD_PING, ping_data, 4, packet, sizeof(packet));

    uint8_t encoded[128];
    size_t enc_len = cobs_encode(packet, pkt_len, encoded, sizeof(encoded));
    encoded[enc_len++] = COBS_DELIMITER;

    host_protocol_rx_bytes(&proto, encoded, enc_len);

    uint8_t decoded[64];
    size_t decoded_len;
    decode_response(decoded, sizeof(decoded), &decoded_len);

    uint8_t cmd;
    host_status_t status;
    uint8_t *payload;
    size_t payload_len;

    bool result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);
    ASSERT(result);
    ASSERT_EQ(cmd, HOST_CMD_PING);
    ASSERT_EQ(status, HOST_STATUS_OK);
    ASSERT_EQ(payload_len, 4);
    ASSERT_MEM_EQ(payload, ping_data, 4);
    return true;
}

static bool test_handle_get_status(void) {
    reset_mocks();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, mock_start_advertising, mock_stop_advertising,
                                 mock_disconnect, mock_set_led, mock_reset, mock_send);

    proto.conn_state = HOST_CONN_READY;
    proto.player_number = 1;

    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(HOST_CMD_GET_STATUS, NULL, 0, packet, sizeof(packet));

    uint8_t encoded[128];
    size_t enc_len = cobs_encode(packet, pkt_len, encoded, sizeof(encoded));
    encoded[enc_len++] = COBS_DELIMITER;

    host_protocol_rx_bytes(&proto, encoded, enc_len);

    uint8_t decoded[64];
    size_t decoded_len;
    decode_response(decoded, sizeof(decoded), &decoded_len);

    uint8_t cmd;
    host_status_t status;
    uint8_t *payload;
    size_t payload_len;

    bool result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);
    ASSERT(result);
    ASSERT_EQ(cmd, HOST_CMD_GET_STATUS);
    ASSERT_EQ(status, HOST_STATUS_OK);
    ASSERT_EQ(payload_len, 10);
    ASSERT_EQ(payload[0], HOST_CONN_READY);
    ASSERT_EQ(payload[1], CONTROLLER_PRO);
    ASSERT_EQ(payload[2], 1);
    return true;
}

static bool test_handle_start_advertising(void) {
    reset_mocks();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, mock_start_advertising, mock_stop_advertising,
                                 mock_disconnect, mock_set_led, mock_reset, mock_send);

    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(HOST_CMD_START_ADVERTISING, NULL, 0, packet, sizeof(packet));

    uint8_t encoded[128];
    size_t enc_len = cobs_encode(packet, pkt_len, encoded, sizeof(encoded));
    encoded[enc_len++] = COBS_DELIMITER;

    host_protocol_rx_bytes(&proto, encoded, enc_len);

    ASSERT(g_advertising_started);
    return true;
}

static bool test_handle_set_all_buttons(void) {
    reset_mocks();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, mock_start_advertising, mock_stop_advertising,
                                 mock_disconnect, mock_set_led, mock_reset, mock_send);

    uint8_t buttons[] = {0x08, 0x00, 0x00};
    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(HOST_CMD_SET_ALL_BUTTONS, buttons, 3, packet, sizeof(packet));

    uint8_t encoded[128];
    size_t enc_len = cobs_encode(packet, pkt_len, encoded, sizeof(encoded));
    encoded[enc_len++] = COBS_DELIMITER;

    host_protocol_rx_bytes(&proto, encoded, enc_len);

    ASSERT_MEM_EQ(controller.buttons, buttons, 3);
    return true;
}

static bool test_handle_clear_buttons(void) {
    reset_mocks();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    controller.buttons[0] = 0xFF;
    controller.buttons[1] = 0xFF;
    controller.buttons[2] = 0xFF;

    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, mock_start_advertising, mock_stop_advertising,
                                 mock_disconnect, mock_set_led, mock_reset, mock_send);

    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(HOST_CMD_CLEAR_BUTTONS, NULL, 0, packet, sizeof(packet));

    uint8_t encoded[128];
    size_t enc_len = cobs_encode(packet, pkt_len, encoded, sizeof(encoded));
    encoded[enc_len++] = COBS_DELIMITER;

    host_protocol_rx_bytes(&proto, encoded, enc_len);

    ASSERT_EQ(controller.buttons[0], 0);
    ASSERT_EQ(controller.buttons[1], 0);
    ASSERT_EQ(controller.buttons[2], 0);
    return true;
}

static bool test_handle_set_stick(void) {
    reset_mocks();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, mock_start_advertising, mock_stop_advertising,
                                 mock_disconnect, mock_set_led, mock_reset, mock_send);

    uint8_t payload[] = {0x00, 0x00, 0x08, 0xFF, 0x0F};
    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(HOST_CMD_SET_STICK, payload, 5, packet, sizeof(packet));

    uint8_t encoded[128];
    size_t enc_len = cobs_encode(packet, pkt_len, encoded, sizeof(encoded));
    encoded[enc_len++] = COBS_DELIMITER;

    host_protocol_rx_bytes(&proto, encoded, enc_len);

    ASSERT_EQ(controller.left_stick.h, 0x0800);
    ASSERT_EQ(controller.left_stick.v, 0x0FFF);
    return true;
}

static bool test_handle_unknown_command(void) {
    reset_mocks();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, mock_start_advertising, mock_stop_advertising,
                                 mock_disconnect, mock_set_led, mock_reset, mock_send);

    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(0xAA, NULL, 0, packet, sizeof(packet));

    uint8_t encoded[128];
    size_t enc_len = cobs_encode(packet, pkt_len, encoded, sizeof(encoded));
    encoded[enc_len++] = COBS_DELIMITER;

    host_protocol_rx_bytes(&proto, encoded, enc_len);

    uint8_t decoded[64];
    size_t decoded_len;
    decode_response(decoded, sizeof(decoded), &decoded_len);

    uint8_t cmd;
    host_status_t status;
    uint8_t *payload;
    size_t payload_len;

    bool result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);
    ASSERT(result);
    ASSERT_EQ(cmd, 0xAA);
    ASSERT_EQ(status, HOST_STATUS_UNKNOWN_CMD);
    return true;
}

static bool test_handle_set_led(void) {
    reset_mocks();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, mock_start_advertising, mock_stop_advertising,
                                 mock_disconnect, mock_set_led, mock_reset, mock_send);

    uint8_t payload[] = {HOST_LED_BLINK_FAST};
    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(HOST_CMD_SET_LED, payload, 1, packet, sizeof(packet));

    uint8_t encoded[128];
    size_t enc_len = cobs_encode(packet, pkt_len, encoded, sizeof(encoded));
    encoded[enc_len++] = COBS_DELIMITER;

    host_protocol_rx_bytes(&proto, encoded, enc_len);

    ASSERT_EQ(g_led_mode, HOST_LED_BLINK_FAST);
    return true;
}

static bool test_partial_packet_reception(void) {
    reset_mocks();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, mock_start_advertising, mock_stop_advertising,
                                 mock_disconnect, mock_set_led, mock_reset, mock_send);

    uint8_t packet[64];
    size_t pkt_len = host_protocol_build_packet(HOST_CMD_PING, NULL, 0, packet, sizeof(packet));

    uint8_t encoded[128];
    size_t enc_len = cobs_encode(packet, pkt_len, encoded, sizeof(encoded));
    encoded[enc_len++] = COBS_DELIMITER;

    for (size_t i = 0; i < enc_len; i++) {
        host_protocol_rx_byte(&proto, encoded[i]);
    }

    ASSERT(g_sent_len > 0);
    return true;
}

TEST_MAIN_BEGIN("Protocol")
    RUN_TEST(test_build_packet_simple);
    RUN_TEST(test_build_packet_with_payload);
    RUN_TEST(test_build_response_ok);
    RUN_TEST(test_build_response_with_payload);
    RUN_TEST(test_parse_packet_valid);
    RUN_TEST(test_parse_packet_with_payload);
    RUN_TEST(test_parse_packet_bad_length);
    RUN_TEST(test_parse_packet_bad_crc);
    RUN_TEST(test_parse_response_valid);
    RUN_TEST(test_protocol_init);
    RUN_TEST(test_handle_ping_empty);
    RUN_TEST(test_handle_ping_echo);
    RUN_TEST(test_handle_get_status);
    RUN_TEST(test_handle_start_advertising);
    RUN_TEST(test_handle_set_all_buttons);
    RUN_TEST(test_handle_clear_buttons);
    RUN_TEST(test_handle_set_stick);
    RUN_TEST(test_handle_unknown_command);
    RUN_TEST(test_handle_set_led);
    RUN_TEST(test_partial_packet_reception);
TEST_MAIN_END()
