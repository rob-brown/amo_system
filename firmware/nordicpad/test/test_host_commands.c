#include "test_framework.h"

#include "host/host_commands.h"

typedef struct {
    controller_input_t input;
    amiibo_store_t amiibo;
    host_commands_t commands;
    host_connection_state_t state;
} fixture_t;

static fixture_t fixture;

static host_connection_state_t current_state(void *context) {
    return ((fixture_t *)context)->state;
}

static void reset_fixture(void) {
    memset(&fixture, 0, sizeof(fixture));
    controller_input_init(&fixture.input);
    amiibo_store_init(&fixture.amiibo);
    fixture.state = HOST_CONNECTION_READY;
    host_commands_init(&fixture.commands, &fixture.input, &fixture.amiibo, current_state, &fixture);
}

static host_response_t run(uint8_t command, const uint8_t *payload, size_t length) {
    host_request_t request = {command, payload, length};
    return host_commands_handle(&fixture.commands, &request);
}

static bool test_unknown_command_is_reported(void) {
    // Arrange
    reset_fixture();

    // Act
    host_response_t response = run(0x7E, NULL, 0);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_UNKNOWN_CMD);
    ASSERT_EQ(response.length, 0);
    return true;
}

static bool test_ping_echoes_its_payload(void) {
    // Arrange
    reset_fixture();
    const uint8_t payload[] = {1, 2, 3, 0, 5};

    // Act
    host_response_t response = run(HOST_CMD_PING, payload, sizeof(payload));

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_OK);
    ASSERT_EQ(response.length, sizeof(payload));
    ASSERT_MEM_EQ(response.payload, payload, sizeof(payload));
    return true;
}

static bool test_status_reports_connection_controller_and_amiibo(void) {
    // Arrange
    reset_fixture();
    fixture.state = HOST_CONNECTION_PAIRING;

    // Act
    host_response_t response = run(HOST_CMD_GET_STATUS, NULL, 0);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_OK);
    ASSERT_EQ(response.length, 10);
    ASSERT_EQ(response.payload[0], HOST_CONNECTION_PAIRING);
    ASSERT_EQ(response.payload[1], HOST_CONTROLLER_JOYCON_R);
    ASSERT_EQ(response.payload[2], 0xFF);
    ASSERT_EQ(response.payload[3], 0);
    return true;
}

static bool test_status_reports_the_configured_controller_type(void) {
    // Arrange
    reset_fixture();

    // Act
    host_commands_set_controller_type(&fixture.commands, CONTROLLER_TYPE_PRO_CONTROLLER);
    uint8_t pro = run(HOST_CMD_GET_STATUS, NULL, 0).payload[1];
    host_commands_set_controller_type(&fixture.commands, CONTROLLER_TYPE_JOYCON_L);
    uint8_t joycon_left = run(HOST_CMD_GET_STATUS, NULL, 0).payload[1];

    // Assert
    ASSERT_EQ(pro, HOST_CONTROLLER_PRO);
    ASSERT_EQ(joycon_left, HOST_CONTROLLER_JOYCON_L);
    return true;
}

static bool test_version_starts_with_major_minor_patch(void) {
    // Arrange
    reset_fixture();

    // Act
    host_response_t response = run(HOST_CMD_GET_VERSION, NULL, 0);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_OK);
    ASSERT_EQ(response.payload[0], 0);
    ASSERT_EQ(response.payload[1], 1);
    ASSERT_EQ(response.payload[2], 0);
    ASSERT(response.length > 3);
    return true;
}

static bool test_short_payloads_are_invalid(void) {
    // Arrange
    reset_fixture();
    const uint8_t two_bytes[] = {0, 0};

    // Act
    host_response_t buttons = run(HOST_CMD_SET_BUTTONS, two_bytes, sizeof(two_bytes));
    host_response_t stick = run(HOST_CMD_SET_STICK, two_bytes, sizeof(two_bytes));
    host_response_t press = run(HOST_CMD_PRESS_BUTTON, two_bytes, sizeof(two_bytes));

    // Assert
    ASSERT_EQ(buttons.status, HOST_STATUS_INVALID_PARAMS);
    ASSERT_EQ(stick.status, HOST_STATUS_INVALID_PARAMS);
    ASSERT_EQ(press.status, HOST_STATUS_INVALID_PARAMS);
    return true;
}

static bool test_set_buttons_then_input_state_round_trips(void) {
    // Arrange
    reset_fixture();
    const uint8_t request[] = {0x08, 0x10, 0x00, 0xFF, 0xFF, 0xFF};

    // Act
    host_response_t set = run(HOST_CMD_SET_BUTTONS, request, sizeof(request));
    host_response_t state = run(HOST_CMD_GET_INPUT_STATE, NULL, 0);

    // Assert
    ASSERT_EQ(set.status, HOST_STATUS_OK);
    ASSERT_EQ(state.length, 11);
    ASSERT_EQ(state.payload[0], 0x08);
    ASSERT_EQ(state.payload[1], 0x10);
    return true;
}

static bool test_set_all_buttons_replaces_the_whole_state(void) {
    // Arrange
    reset_fixture();
    run(HOST_CMD_SET_ALL_BUTTONS, ((const uint8_t[]){0xFF, 0xFF, 0xFF}), 3);

    // Act
    run(HOST_CMD_SET_ALL_BUTTONS, ((const uint8_t[]){0x01, 0x00, 0x00}), 3);
    host_response_t state = run(HOST_CMD_GET_INPUT_STATE, NULL, 0);

    // Assert
    ASSERT_EQ(state.payload[0], 0x01);
    ASSERT_EQ(state.payload[1], 0x00);
    return true;
}

static bool test_set_stick_is_little_endian_and_visible_in_input_state(void) {
    // Arrange
    reset_fixture();
    const uint8_t request[] = {HOST_STICK_RIGHT, 0x34, 0x02, 0x78, 0x01};

    // Act
    host_response_t set = run(HOST_CMD_SET_STICK, request, sizeof(request));
    host_response_t state = run(HOST_CMD_GET_INPUT_STATE, NULL, 0);

    // Assert
    ASSERT_EQ(set.status, HOST_STATUS_OK);
    ASSERT_EQ(state.payload[7], 0x34);
    ASSERT_EQ(state.payload[8], 0x02);
    ASSERT_EQ(state.payload[9], 0x78);
    ASSERT_EQ(state.payload[10], 0x01);
    return true;
}

static bool test_press_button_shows_up_in_the_next_report(void) {
    // Arrange
    reset_fixture();
    uint8_t report[INPUT_REPORT_SIZE];

    // Act
    host_response_t press = run(HOST_CMD_PRESS_BUTTON, ((const uint8_t[]){0x03, 0x64, 0x00}), 3);
    controller_input_build_report(&fixture.input, report);

    // Assert
    ASSERT_EQ(press.status, HOST_STATUS_OK);
    ASSERT_EQ(report[2], 0x04);
    return true;
}

static bool test_unknown_button_and_preset_are_invalid(void) {
    // Arrange
    reset_fixture();

    // Act
    host_response_t button = run(HOST_CMD_PRESS_BUTTON, ((const uint8_t[]){0x40, 0x00, 0x00}), 3);
    host_response_t preset = run(HOST_CMD_SET_STICK_PRESET, ((const uint8_t[]){HOST_STICK_RIGHT, 0x20}), 2);

    // Assert
    ASSERT_EQ(button.status, HOST_STATUS_INVALID_PARAMS);
    ASSERT_EQ(preset.status, HOST_STATUS_INVALID_PARAMS);
    return true;
}

static bool test_clear_buttons_releases_everything(void) {
    // Arrange
    reset_fixture();
    run(HOST_CMD_SET_ALL_BUTTONS, ((const uint8_t[]){0xFF, 0xFF, 0xFF}), 3);

    // Act
    host_response_t clear = run(HOST_CMD_CLEAR_BUTTONS, NULL, 0);
    host_response_t state = run(HOST_CMD_GET_INPUT_STATE, NULL, 0);

    // Assert
    ASSERT_EQ(clear.status, HOST_STATUS_OK);
    ASSERT_EQ(state.payload[0], 0);
    ASSERT_EQ(state.payload[1], 0);
    ASSERT_EQ(state.payload[2], 0);
    return true;
}

static bool test_amiibo_status_is_empty_at_first(void) {
    // Arrange
    reset_fixture();

    // Act
    host_response_t response = run(HOST_CMD_AMIIBO_GET_STATUS, NULL, 0);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_OK);
    ASSERT_EQ(response.length, 10);
    ASSERT_EQ(response.payload[0], HOST_AMIIBO_NONE);
    return true;
}

static bool test_chunked_amiibo_upload_ends_with_the_uid(void) {
    // Arrange
    reset_fixture();
    uint8_t dump[AMIIBO_V2_SIZE];
    for (size_t index = 0; index < sizeof(dump); index++) {
        dump[index] = (uint8_t)(index + 1);
    }
    uint8_t size_le[] = {AMIIBO_V2_SIZE & 0xFF, AMIIBO_V2_SIZE >> 8};

    // Act
    host_response_t start = run(HOST_CMD_AMIIBO_LOAD_START, size_le, sizeof(size_le));
    uint8_t advertised_chunk_size = start.payload[0];
    host_response_t last = {0};
    for (size_t offset = 0, index = 0; offset < sizeof(dump); offset += AMIIBO_CHUNK_SIZE, index++) {
        uint8_t chunk[1 + AMIIBO_CHUNK_SIZE];
        size_t length = sizeof(dump) - offset < AMIIBO_CHUNK_SIZE ? sizeof(dump) - offset : AMIIBO_CHUNK_SIZE;
        chunk[0] = (uint8_t)index;
        memcpy(&chunk[1], &dump[offset], length);
        last = run(HOST_CMD_AMIIBO_LOAD_CHUNK, chunk, 1 + length);
    }
    host_response_t finish = run(HOST_CMD_AMIIBO_LOAD_FINISH, NULL, 0);

    // Assert
    ASSERT_EQ(start.status, HOST_STATUS_OK);
    ASSERT_EQ(advertised_chunk_size, AMIIBO_CHUNK_SIZE);
    ASSERT_EQ(last.status, HOST_STATUS_OK);
    ASSERT_EQ(finish.status, HOST_STATUS_OK);
    ASSERT_EQ(finish.length, AMIIBO_UID_SIZE);
    ASSERT_MEM_EQ(finish.payload, ((const uint8_t[]){dump[0], dump[1], dump[2], dump[4], dump[5], dump[6], dump[7]}), AMIIBO_UID_SIZE);
    ASSERT(amiibo_store_is_loaded(&fixture.amiibo));
    return true;
}

static bool test_single_packet_amiibo_load_and_clear(void) {
    // Arrange
    reset_fixture();
    uint8_t request[2 + AMIIBO_V2_SIZE];
    request[0] = AMIIBO_V2_SIZE & 0xFF;
    request[1] = AMIIBO_V2_SIZE >> 8;
    memset(&request[2], 0x5A, AMIIBO_V2_SIZE);

    // Act
    host_response_t load = run(HOST_CMD_AMIIBO_LOAD, request, sizeof(request));
    host_response_t status = run(HOST_CMD_AMIIBO_GET_STATUS, NULL, 0);
    uint8_t reported_state = status.payload[0];
    uint8_t reported_size_low = status.payload[8];
    uint8_t reported_size_high = status.payload[9];
    host_response_t clear = run(HOST_CMD_AMIIBO_CLEAR, NULL, 0);

    // Assert
    ASSERT_EQ(load.status, HOST_STATUS_OK);
    ASSERT_EQ(reported_state, HOST_AMIIBO_LOADED);
    ASSERT_EQ(reported_size_low, AMIIBO_V2_SIZE & 0xFF);
    ASSERT_EQ(reported_size_high, AMIIBO_V2_SIZE >> 8);
    ASSERT_EQ(clear.status, HOST_STATUS_OK);
    ASSERT(!amiibo_store_is_loaded(&fixture.amiibo));
    return true;
}

static bool test_bad_amiibo_size_and_out_of_order_chunk_are_refused(void) {
    // Arrange
    reset_fixture();

    // Act
    host_response_t bad_size = run(HOST_CMD_AMIIBO_LOAD_START, ((const uint8_t[]){0x00, 0x01}), 2);
    host_response_t no_start = run(HOST_CMD_AMIIBO_LOAD_CHUNK, ((const uint8_t[]){0x00, 0x11}), 2);
    host_response_t early_finish = run(HOST_CMD_AMIIBO_LOAD_FINISH, NULL, 0);

    // Assert
    ASSERT_EQ(bad_size.status, HOST_STATUS_AMIIBO_ERROR);
    ASSERT_EQ(no_start.status, HOST_STATUS_INVALID_PARAMS);
    ASSERT_EQ(early_finish.status, HOST_STATUS_INVALID_PARAMS);
    return true;
}

static controller_colors_t received_colors;

static void remember_colors(void *context, const controller_colors_t *colors) {
    (void)context;
    received_colors = *colors;
}

static bool test_set_colors_hands_body_buttons_highlight_grip_to_the_app(void) {
    // Arrange
    reset_fixture();
    const host_appearance_t appearance = {remember_colors, NULL};
    host_commands_set_appearance(&fixture.commands, &appearance);
    const uint8_t payload[12] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};

    // Act
    host_response_t response = run(HOST_CMD_SET_COLORS, payload, sizeof(payload));

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_OK);
    ASSERT_MEM_EQ(received_colors.body, ((const uint8_t[]){1, 2, 3}), 3);
    ASSERT_MEM_EQ(received_colors.grip, ((const uint8_t[]){10, 11, 12}), 3);
    return true;
}

static bool test_set_colors_needs_twelve_bytes(void) {
    // Arrange
    reset_fixture();
    const uint8_t payload[11] = {0};

    // Act
    host_response_t response = run(HOST_CMD_SET_COLORS, payload, sizeof(payload));

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_INVALID_PARAMS);
    return true;
}

static host_reboot_target_t requested_target;
static int reboot_count;

static void remember_reboot(void *context, host_reboot_target_t target) {
    (void)context;
    requested_target = target;
    reboot_count++;
}

static bool test_reset_asks_the_platform_to_reboot_into_the_requested_target(void) {
    // Arrange
    reset_fixture();
    reboot_count = 0;
    const host_system_t system = {remember_reboot, NULL};
    host_commands_set_system(&fixture.commands, &system);

    // Act
    host_response_t response = run(HOST_CMD_RESET, ((const uint8_t[]){HOST_REBOOT_BOOTLOADER}), 1);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_OK);
    ASSERT_EQ(reboot_count, 1);
    ASSERT_EQ(requested_target, HOST_REBOOT_BOOTLOADER);
    return true;
}

static bool test_reset_rejects_an_unknown_target_without_rebooting(void) {
    // Arrange
    reset_fixture();
    reboot_count = 0;
    const host_system_t system = {remember_reboot, NULL};
    host_commands_set_system(&fixture.commands, &system);

    // Act
    host_response_t response = run(HOST_CMD_RESET, ((const uint8_t[]){0x7F}), 1);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_INVALID_PARAMS);
    ASSERT_EQ(reboot_count, 0);
    return true;
}

static bool test_reset_fails_when_the_platform_cannot_reboot(void) {
    // Arrange
    reset_fixture();

    // Act
    host_response_t response = run(HOST_CMD_RESET, NULL, 0);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_ERROR);
    return true;
}

typedef struct {
    int started;
    int stopped;
    int reconnects;
    int forgotten;
    uint8_t reconnect_status;
    bool forget_succeeds;
} radio_spy_t;

static radio_spy_t radio_spy;

static void spy_start(void *context) {
    ((radio_spy_t *)context)->started++;
}

static void spy_stop(void *context) {
    ((radio_spy_t *)context)->stopped++;
}

static uint8_t spy_reconnect(void *context) {
    radio_spy_t *spy = context;
    spy->reconnects++;
    return spy->reconnect_status;
}

static bool spy_forget(void *context) {
    radio_spy_t *spy = context;
    spy->forgotten++;
    return spy->forget_succeeds;
}

static void attach_radio_spy(void) {
    memset(&radio_spy, 0, sizeof(radio_spy));
    radio_spy.reconnect_status = HOST_STATUS_OK;
    radio_spy.forget_succeeds = true;
    const host_radio_t radio = {spy_start, spy_stop, spy_reconnect, spy_forget, &radio_spy};
    host_commands_set_radio(&fixture.commands, &radio);
}

static bool test_start_advertising_asks_the_radio_to_advertise(void) {
    // Arrange
    reset_fixture();
    attach_radio_spy();

    // Act
    host_response_t response = run(HOST_CMD_START_ADVERTISING, NULL, 0);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_OK);
    ASSERT_EQ(response.length, 0);
    ASSERT_EQ(radio_spy.started, 1);
    ASSERT_EQ(radio_spy.stopped, 0);
    return true;
}

static bool test_stop_advertising_asks_the_radio_to_stop(void) {
    // Arrange
    reset_fixture();
    attach_radio_spy();

    // Act
    host_response_t response = run(HOST_CMD_STOP_ADVERTISING, NULL, 0);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_OK);
    ASSERT_EQ(radio_spy.stopped, 1);
    ASSERT_EQ(radio_spy.started, 0);
    return true;
}

static bool test_reconnect_reports_what_the_radio_decided(void) {
    // Arrange
    reset_fixture();
    attach_radio_spy();
    const uint8_t outcomes[] = {HOST_STATUS_OK, HOST_STATUS_BUSY, HOST_STATUS_ERROR};
    uint8_t statuses[sizeof(outcomes)];

    // Act
    for (size_t index = 0; index < sizeof(outcomes); index++) {
        radio_spy.reconnect_status = outcomes[index];
        statuses[index] = run(HOST_CMD_RECONNECT, NULL, 0).status;
    }

    // Assert
    ASSERT_MEM_EQ(statuses, outcomes, sizeof(outcomes));
    ASSERT_EQ(radio_spy.reconnects, 3);
    return true;
}

static bool test_forget_bonding_succeeds_when_the_radio_forgets(void) {
    // Arrange
    reset_fixture();
    attach_radio_spy();

    // Act
    host_response_t response = run(HOST_CMD_FORGET_BONDING, NULL, 0);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_OK);
    ASSERT_EQ(radio_spy.forgotten, 1);
    return true;
}

static bool test_forget_bonding_fails_when_the_radio_cannot_forget(void) {
    // Arrange
    reset_fixture();
    attach_radio_spy();
    radio_spy.forget_succeeds = false;

    // Act
    host_response_t response = run(HOST_CMD_FORGET_BONDING, NULL, 0);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_ERROR);
    return true;
}

static bool test_radio_commands_fail_without_a_radio(void) {
    // Arrange
    reset_fixture();

    // Act
    host_response_t start = run(HOST_CMD_START_ADVERTISING, NULL, 0);
    host_response_t stop = run(HOST_CMD_STOP_ADVERTISING, NULL, 0);
    host_response_t reconnect = run(HOST_CMD_RECONNECT, NULL, 0);
    host_response_t forget = run(HOST_CMD_FORGET_BONDING, NULL, 0);

    // Assert
    ASSERT_EQ(start.status, HOST_STATUS_ERROR);
    ASSERT_EQ(stop.status, HOST_STATUS_ERROR);
    ASSERT_EQ(reconnect.status, HOST_STATUS_ERROR);
    ASSERT_EQ(forget.status, HOST_STATUS_ERROR);
    return true;
}

TEST_MAIN_BEGIN("host_commands")
    RUN_TEST(test_start_advertising_asks_the_radio_to_advertise);
    RUN_TEST(test_stop_advertising_asks_the_radio_to_stop);
    RUN_TEST(test_reconnect_reports_what_the_radio_decided);
    RUN_TEST(test_forget_bonding_succeeds_when_the_radio_forgets);
    RUN_TEST(test_forget_bonding_fails_when_the_radio_cannot_forget);
    RUN_TEST(test_radio_commands_fail_without_a_radio);
    RUN_TEST(test_reset_asks_the_platform_to_reboot_into_the_requested_target);
    RUN_TEST(test_reset_rejects_an_unknown_target_without_rebooting);
    RUN_TEST(test_reset_fails_when_the_platform_cannot_reboot);
    RUN_TEST(test_set_colors_hands_body_buttons_highlight_grip_to_the_app);
    RUN_TEST(test_set_colors_needs_twelve_bytes);
    RUN_TEST(test_unknown_command_is_reported);
    RUN_TEST(test_ping_echoes_its_payload);
    RUN_TEST(test_status_reports_connection_controller_and_amiibo);
    RUN_TEST(test_status_reports_the_configured_controller_type);
    RUN_TEST(test_version_starts_with_major_minor_patch);
    RUN_TEST(test_short_payloads_are_invalid);
    RUN_TEST(test_set_buttons_then_input_state_round_trips);
    RUN_TEST(test_set_all_buttons_replaces_the_whole_state);
    RUN_TEST(test_set_stick_is_little_endian_and_visible_in_input_state);
    RUN_TEST(test_press_button_shows_up_in_the_next_report);
    RUN_TEST(test_unknown_button_and_preset_are_invalid);
    RUN_TEST(test_clear_buttons_releases_everything);
    RUN_TEST(test_amiibo_status_is_empty_at_first);
    RUN_TEST(test_chunked_amiibo_upload_ends_with_the_uid);
    RUN_TEST(test_single_packet_amiibo_load_and_clear);
    RUN_TEST(test_bad_amiibo_size_and_out_of_order_chunk_are_refused);
TEST_MAIN_END()
