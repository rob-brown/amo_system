#include "test_framework.h"
#include "../src/cobs.h"
#include "../src/crc8.h"
#include "../src/host_protocol.h"

static uint8_t g_sent_data[8192];
static size_t g_sent_len = 0;
static uint8_t g_amiibo_buffer[2100];

static void mock_send(const uint8_t *data, size_t len) {
    memcpy(g_sent_data + g_sent_len, data, len);
    g_sent_len += len;
}

static void reset_state(void) {
    g_sent_len = 0;
    memset(g_sent_data, 0, sizeof(g_sent_data));
}

static size_t extract_next_packet(uint8_t *decoded, size_t *decoded_len, size_t start_offset) {
    size_t delim_pos = start_offset;
    while (delim_pos < g_sent_len && g_sent_data[delim_pos] != COBS_DELIMITER) {
        delim_pos++;
    }

    if (delim_pos >= g_sent_len || delim_pos == start_offset) {
        return 0;
    }

    *decoded_len = cobs_decode(g_sent_data + start_offset, delim_pos - start_offset, decoded, HOST_PROTO_MAX_PACKET);
    return delim_pos + 1;
}

static void send_command(host_protocol_t *proto, uint8_t cmd, const uint8_t *payload, size_t payload_len) {
    uint8_t packet[HOST_PROTO_MAX_PACKET];
    size_t pkt_len = host_protocol_build_packet(cmd, payload, payload_len, packet, sizeof(packet));

    uint8_t encoded[HOST_PROTO_MAX_PACKET + 10];
    size_t enc_len = cobs_encode(packet, pkt_len, encoded, sizeof(encoded));
    encoded[enc_len++] = COBS_DELIMITER;

    host_protocol_rx_bytes(proto, encoded, enc_len);
}

static bool test_full_connection_flow(void) {
    reset_state();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, NULL, NULL, NULL, NULL, NULL, mock_send);

    send_command(&proto, HOST_CMD_GET_STATUS, NULL, 0);

    uint8_t decoded[64];
    size_t decoded_len;
    extract_next_packet(decoded, &decoded_len, 0);

    uint8_t cmd;
    host_status_t status;
    uint8_t *payload;
    size_t payload_len;
    bool result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);

    ASSERT(result);
    ASSERT_EQ(payload[0], HOST_CONN_DISCONNECTED);

    reset_state();
    send_command(&proto, HOST_CMD_START_ADVERTISING, NULL, 0);

    host_protocol_set_connection_state(&proto, HOST_CONN_ADVERTISING, NULL);

    reset_state();
    send_command(&proto, HOST_CMD_GET_STATUS, NULL, 0);
    extract_next_packet(decoded, &decoded_len, 0);
    result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);
    ASSERT(result);
    ASSERT_EQ(payload[0], HOST_CONN_ADVERTISING);

    uint8_t switch_addr[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66};
    host_protocol_set_connection_state(&proto, HOST_CONN_READY, switch_addr);
    host_protocol_set_player_number(&proto, 1);

    reset_state();
    send_command(&proto, HOST_CMD_GET_STATUS, NULL, 0);
    extract_next_packet(decoded, &decoded_len, 0);
    result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);
    ASSERT(result);
    ASSERT_EQ(payload[0], HOST_CONN_READY);
    ASSERT_EQ(payload[1], CONTROLLER_PRO);
    ASSERT_EQ(payload[2], 1);
    ASSERT_MEM_EQ(payload + 4, switch_addr, 6);

    return true;
}

static bool test_button_sequence(void) {
    reset_state();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, NULL, NULL, NULL, NULL, NULL, mock_send);

    uint8_t buttons_a[] = {0x08, 0x00, 0x00};
    send_command(&proto, HOST_CMD_SET_ALL_BUTTONS, buttons_a, 3);
    ASSERT(controller_get_button(&controller, BTN_A));
    ASSERT(!controller_get_button(&controller, BTN_B));

    uint8_t buttons_b[] = {0x04, 0x00, 0x00};
    send_command(&proto, HOST_CMD_SET_ALL_BUTTONS, buttons_b, 3);
    ASSERT(!controller_get_button(&controller, BTN_A));
    ASSERT(controller_get_button(&controller, BTN_B));

    send_command(&proto, HOST_CMD_CLEAR_BUTTONS, NULL, 0);
    ASSERT(!controller_get_button(&controller, BTN_A));
    ASSERT(!controller_get_button(&controller, BTN_B));

    reset_state();
    send_command(&proto, HOST_CMD_GET_INPUT_STATE, NULL, 0);

    uint8_t decoded[64];
    size_t decoded_len;
    extract_next_packet(decoded, &decoded_len, 0);

    uint8_t cmd;
    host_status_t status;
    uint8_t *payload;
    size_t payload_len;
    bool result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);

    ASSERT(result);
    ASSERT_EQ(cmd, HOST_CMD_GET_INPUT_STATE);
    ASSERT_EQ(payload[0], 0x00);
    ASSERT_EQ(payload[1], 0x00);
    ASSERT_EQ(payload[2], 0x00);

    return true;
}

static bool test_stick_control(void) {
    reset_state();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, NULL, NULL, NULL, NULL, NULL, mock_send);

    uint8_t stick_payload[] = {0x00, 0x00, 0x08, 0x00, 0x08};
    send_command(&proto, HOST_CMD_SET_STICK, stick_payload, 5);

    ASSERT_EQ(controller.left_stick.h, 0x0800);
    ASSERT_EQ(controller.left_stick.v, 0x0800);

    uint8_t preset_up[] = {0x00, HOST_STICK_UP};
    send_command(&proto, HOST_CMD_SET_STICK_PRESET, preset_up, 2);

    ASSERT(controller.left_stick.v > 0x0800);

    uint8_t preset_center[] = {0x00, HOST_STICK_CENTER};
    send_command(&proto, HOST_CMD_SET_STICK_PRESET, preset_center, 2);

    ASSERT_EQ(controller.left_stick.h, 0x0800);
    ASSERT_EQ(controller.left_stick.v, 0x0800);

    return true;
}

static bool test_amiibo_load_small(void) {
    reset_state();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, NULL, NULL, NULL, NULL, NULL, mock_send);
    host_protocol_set_amiibo_buffer(&proto, g_amiibo_buffer, sizeof(g_amiibo_buffer));

    uint8_t amiibo_data[540];
    for (int i = 0; i < 540; i++) {
        amiibo_data[i] = i & 0xFF;
    }

    uint8_t payload[544];
    payload[0] = 0x1C;
    payload[1] = 0x02;
    memcpy(payload + 2, amiibo_data, 540);

    send_command(&proto, HOST_CMD_AMIIBO_LOAD, payload, 542);

    ASSERT_EQ(proto.amiibo_state, HOST_AMIIBO_LOADED);
    ASSERT_EQ(proto.amiibo_size, 540);
    ASSERT_MEM_EQ(proto.amiibo_data, amiibo_data, 540);

    return true;
}

static bool test_amiibo_load_chunked_540(void) {
    reset_state();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, NULL, NULL, NULL, NULL, NULL, mock_send);
    host_protocol_set_amiibo_buffer(&proto, g_amiibo_buffer, sizeof(g_amiibo_buffer));

    uint8_t amiibo_data[540];
    for (int i = 0; i < 540; i++) {
        amiibo_data[i] = (i * 7) & 0xFF;
    }

    uint8_t start_payload[] = {0x1C, 0x02};
    send_command(&proto, HOST_CMD_AMIIBO_LOAD_START, start_payload, 2);

    uint8_t decoded[64];
    size_t decoded_len;
    extract_next_packet(decoded, &decoded_len, 0);

    uint8_t cmd;
    host_status_t status;
    uint8_t *payload;
    size_t payload_len;
    bool result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);
    ASSERT(result);
    ASSERT_EQ(status, HOST_STATUS_OK);
    ASSERT_EQ(payload[0], HOST_PROTO_AMIIBO_CHUNK_SIZE);

    for (int chunk = 0; chunk < 5; chunk++) {
        reset_state();

        uint8_t chunk_payload[130];
        chunk_payload[0] = chunk;
        size_t chunk_size = (chunk < 4) ? 128 : (540 - 4 * 128);
        memcpy(chunk_payload + 1, amiibo_data + chunk * 128, chunk_size);

        send_command(&proto, HOST_CMD_AMIIBO_LOAD_CHUNK, chunk_payload, 1 + chunk_size);

        extract_next_packet(decoded, &decoded_len, 0);
        result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);
        ASSERT(result);
        ASSERT_EQ(status, HOST_STATUS_OK);
    }

    reset_state();
    send_command(&proto, HOST_CMD_AMIIBO_LOAD_FINISH, NULL, 0);

    ASSERT_EQ(proto.amiibo_state, HOST_AMIIBO_LOADED);
    ASSERT_EQ(proto.amiibo_size, 540);
    ASSERT_MEM_EQ(proto.amiibo_data, amiibo_data, 540);

    return true;
}

static bool test_amiibo_load_chunked_2048(void) {
    reset_state();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, NULL, NULL, NULL, NULL, NULL, mock_send);
    host_protocol_set_amiibo_buffer(&proto, g_amiibo_buffer, sizeof(g_amiibo_buffer));

    uint8_t amiibo_data[2048];
    for (int i = 0; i < 2048; i++) {
        amiibo_data[i] = (i * 13) & 0xFF;
    }

    uint8_t start_payload[] = {0x00, 0x08};
    send_command(&proto, HOST_CMD_AMIIBO_LOAD_START, start_payload, 2);

    for (int chunk = 0; chunk < 16; chunk++) {
        reset_state();

        uint8_t chunk_payload[130];
        chunk_payload[0] = chunk;
        memcpy(chunk_payload + 1, amiibo_data + chunk * 128, 128);

        send_command(&proto, HOST_CMD_AMIIBO_LOAD_CHUNK, chunk_payload, 129);
    }

    reset_state();
    send_command(&proto, HOST_CMD_AMIIBO_LOAD_FINISH, NULL, 0);

    ASSERT_EQ(proto.amiibo_state, HOST_AMIIBO_LOADED);
    ASSERT_EQ(proto.amiibo_size, 2048);
    ASSERT_MEM_EQ(proto.amiibo_data, amiibo_data, 2048);

    return true;
}

static bool test_amiibo_clear(void) {
    reset_state();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, NULL, NULL, NULL, NULL, NULL, mock_send);
    host_protocol_set_amiibo_buffer(&proto, g_amiibo_buffer, sizeof(g_amiibo_buffer));

    proto.amiibo_state = HOST_AMIIBO_LOADED;
    proto.amiibo_size = 540;

    send_command(&proto, HOST_CMD_AMIIBO_CLEAR, NULL, 0);

    ASSERT_EQ(proto.amiibo_state, HOST_AMIIBO_NONE);
    ASSERT_EQ(proto.amiibo_size, 0);

    return true;
}

static bool test_get_version(void) {
    reset_state();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, NULL, NULL, NULL, NULL, NULL, mock_send);

    send_command(&proto, HOST_CMD_GET_VERSION, NULL, 0);

    uint8_t decoded[64];
    size_t decoded_len;
    extract_next_packet(decoded, &decoded_len, 0);

    uint8_t cmd;
    host_status_t status;
    uint8_t *payload;
    size_t payload_len;
    bool result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);

    ASSERT(result);
    ASSERT_EQ(cmd, HOST_CMD_GET_VERSION);
    ASSERT_EQ(status, HOST_STATUS_OK);
    ASSERT(payload_len >= 4);
    ASSERT_EQ(payload[0], 1);
    ASSERT_EQ(payload[1], 0);
    ASSERT_EQ(payload[2], 0);

    return true;
}

static bool test_event_connection_changed(void) {
    reset_state();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, NULL, NULL, NULL, NULL, NULL, mock_send);

    uint8_t addr[] = {0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF};
    host_protocol_send_event_connection(&proto, HOST_CONN_READY, addr);

    ASSERT(g_sent_len > 0);

    uint8_t decoded[64];
    size_t decoded_len;
    extract_next_packet(decoded, &decoded_len, 0);

    uint8_t cmd;
    uint8_t *payload;
    size_t payload_len;
    bool result = host_protocol_parse_packet(decoded, decoded_len, &cmd, &payload, &payload_len);

    ASSERT(result);
    ASSERT_EQ(cmd, HOST_EVT_CONNECTION_CHANGED);
    ASSERT_EQ(payload[0], HOST_CONN_READY);
    ASSERT_MEM_EQ(payload + 1, addr, 6);

    return true;
}

static bool test_multiple_commands_sequential(void) {
    reset_state();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, NULL, NULL, NULL, NULL, NULL, mock_send);

    uint8_t ping_data1[] = {0x11};
    send_command(&proto, HOST_CMD_PING, ping_data1, 1);

    uint8_t ping_data2[] = {0x22};
    send_command(&proto, HOST_CMD_PING, ping_data2, 1);

    uint8_t ping_data3[] = {0x33};
    send_command(&proto, HOST_CMD_PING, ping_data3, 1);

    uint8_t decoded[64];
    size_t decoded_len;
    size_t offset = 0;

    offset = extract_next_packet(decoded, &decoded_len, offset);
    ASSERT(offset > 0);

    uint8_t cmd;
    host_status_t status;
    uint8_t *payload;
    size_t payload_len;
    bool result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);
    ASSERT(result);
    ASSERT_EQ(payload[0], 0x11);

    offset = extract_next_packet(decoded, &decoded_len, offset);
    ASSERT(offset > 0);
    result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);
    ASSERT(result);
    ASSERT_EQ(payload[0], 0x22);

    offset = extract_next_packet(decoded, &decoded_len, offset);
    ASSERT(offset > 0);
    result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &payload, &payload_len);
    ASSERT(result);
    ASSERT_EQ(payload[0], 0x33);

    return true;
}

static bool test_cobs_with_zeros_in_payload(void) {
    reset_state();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, NULL, NULL, NULL, NULL, NULL, mock_send);

    uint8_t ping_data[] = {0x00, 0x00, 0x00, 0x00};
    send_command(&proto, HOST_CMD_PING, ping_data, 4);

    uint8_t decoded[64];
    size_t decoded_len;
    extract_next_packet(decoded, &decoded_len, 0);

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

static bool test_controller_type_change(void) {
    reset_state();

    host_protocol_t proto;
    controller_state_t controller;
    controller_state_init(&controller, CONTROLLER_PRO);
    host_protocol_init(&proto, &controller);
    host_protocol_set_callbacks(&proto, NULL, NULL, NULL, NULL, NULL, mock_send);

    ASSERT_EQ(controller.type, CONTROLLER_PRO);

    uint8_t payload[] = {CONTROLLER_JOYCON_L};
    send_command(&proto, HOST_CMD_SET_CONTROLLER_TYPE, payload, 1);

    ASSERT_EQ(controller.type, CONTROLLER_JOYCON_L);

    reset_state();
    send_command(&proto, HOST_CMD_GET_STATUS, NULL, 0);

    uint8_t decoded[64];
    size_t decoded_len;
    extract_next_packet(decoded, &decoded_len, 0);

    uint8_t cmd;
    host_status_t status;
    uint8_t *resp_payload;
    size_t payload_len;
    bool result = host_protocol_parse_response(decoded, decoded_len, &cmd, &status, &resp_payload, &payload_len);
    ASSERT(result);
    ASSERT_EQ(resp_payload[1], CONTROLLER_JOYCON_L);

    return true;
}

TEST_MAIN_BEGIN("Integration")
    RUN_TEST(test_full_connection_flow);
    RUN_TEST(test_button_sequence);
    RUN_TEST(test_stick_control);
    RUN_TEST(test_amiibo_load_small);
    RUN_TEST(test_amiibo_load_chunked_540);
    RUN_TEST(test_amiibo_load_chunked_2048);
    RUN_TEST(test_amiibo_clear);
    RUN_TEST(test_get_version);
    RUN_TEST(test_event_connection_changed);
    RUN_TEST(test_multiple_commands_sequential);
    RUN_TEST(test_cobs_with_zeros_in_payload);
    RUN_TEST(test_controller_type_change);
TEST_MAIN_END()
