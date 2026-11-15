#include "test_framework.h"

#include "host/host_commands.h"

typedef struct {
    controller_input_t input;
    amiibo_store_t amiibo;
    host_commands_t commands;
} fixture_t;

static fixture_t fixture;
static uint8_t dump[AMIIBO_V3_SIZE];

static host_connection_state_t ready_state(void *context) {
    (void)context;
    return HOST_CONNECTION_READY;
}

static void load_dump(size_t size) {
    for (size_t index = 0; index < sizeof(dump); index++) {
        dump[index] = (uint8_t)(index * 13 + 5);
    }
    memset(&fixture, 0, sizeof(fixture));
    controller_input_init(&fixture.input);
    amiibo_store_init(&fixture.amiibo);
    host_commands_init(&fixture.commands, &fixture.input, &fixture.amiibo, ready_state, &fixture);
    amiibo_store_load(&fixture.amiibo, dump, size);
}

static void load_nothing(void) {
    memset(&fixture, 0, sizeof(fixture));
    controller_input_init(&fixture.input);
    amiibo_store_init(&fixture.amiibo);
    host_commands_init(&fixture.commands, &fixture.input, &fixture.amiibo, ready_state, &fixture);
}

static host_response_t run(uint8_t command, const uint8_t *payload, size_t length) {
    host_request_t request = {command, payload, length};
    return host_commands_handle(&fixture.commands, &request);
}

static host_response_t read_chunk(uint8_t index) {
    return run(HOST_CMD_AMIIBO_READ_CHUNK, &index, 1);
}

static bool test_read_reports_the_size_and_the_chunk_size(void) {
    // Arrange
    load_dump(AMIIBO_V3_SIZE);

    // Act
    host_response_t response = run(HOST_CMD_AMIIBO_READ, NULL, 0);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_OK);
    ASSERT_EQ(response.length, 3);
    ASSERT_MEM_EQ(response.payload, ((const uint8_t[]){0x00, 0x08, AMIIBO_CHUNK_SIZE}), 3);
    return true;
}

static bool test_read_without_an_amiibo_is_an_amiibo_error(void) {
    // Arrange
    load_nothing();
    uint8_t index = 0;

    // Act
    host_response_t size = run(HOST_CMD_AMIIBO_READ, NULL, 0);
    host_response_t chunk = run(HOST_CMD_AMIIBO_READ_CHUNK, &index, 1);

    // Assert
    ASSERT_EQ(size.status, HOST_STATUS_AMIIBO_ERROR);
    ASSERT_EQ(chunk.status, HOST_STATUS_AMIIBO_ERROR);
    return true;
}

static bool test_chunks_reassemble_the_whole_dump(void) {
    // Arrange
    load_dump(AMIIBO_V3_SIZE);
    uint8_t rebuilt[AMIIBO_V3_SIZE];
    size_t used = 0;

    // Act
    for (uint8_t index = 0; used < AMIIBO_V3_SIZE; index++) {
        host_response_t response = read_chunk(index);
        ASSERT_EQ(response.status, HOST_STATUS_OK);
        memcpy(&rebuilt[used], response.payload, response.length);
        used += response.length;
    }

    // Assert
    ASSERT_EQ(used, AMIIBO_V3_SIZE);
    ASSERT_MEM_EQ(rebuilt, dump, AMIIBO_V3_SIZE);
    return true;
}

static bool test_the_last_chunk_of_a_v2_dump_is_short(void) {
    // Arrange
    load_dump(AMIIBO_V2_SIZE);

    // Act
    host_response_t response = read_chunk(4);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_OK);
    ASSERT_EQ(response.length, AMIIBO_V2_SIZE - 4 * AMIIBO_CHUNK_SIZE);
    ASSERT_MEM_EQ(response.payload, &dump[4 * AMIIBO_CHUNK_SIZE], response.length);
    return true;
}

static bool test_a_chunk_past_the_end_is_invalid(void) {
    // Arrange
    load_dump(AMIIBO_V2_SIZE);

    // Act
    host_response_t response = read_chunk(5);
    host_response_t missing_index = run(HOST_CMD_AMIIBO_READ_CHUNK, NULL, 0);

    // Assert
    ASSERT_EQ(response.status, HOST_STATUS_INVALID_PARAMS);
    ASSERT_EQ(missing_index.status, HOST_STATUS_INVALID_PARAMS);
    return true;
}

static bool test_a_chunk_shows_changes_made_to_the_stored_dump(void) {
    // Arrange
    load_dump(AMIIBO_V3_SIZE);
    fixture.amiibo.data[0x248] ^= 0xFF;

    // Act
    host_response_t response = read_chunk(0x248 / AMIIBO_CHUNK_SIZE);

    // Assert
    ASSERT_EQ(response.payload[0x248 % AMIIBO_CHUNK_SIZE], (uint8_t)(dump[0x248] ^ 0xFF));
    return true;
}

static bool test_set_readonly_toggles_the_store_flag(void) {
    // Arrange
    load_dump(AMIIBO_V3_SIZE);
    const uint8_t on = 1;
    const uint8_t off = 0;

    // Act
    host_response_t enabled = run(HOST_CMD_AMIIBO_SET_READONLY, &on, 1);
    bool after_enable = fixture.amiibo.readonly;
    host_response_t disabled = run(HOST_CMD_AMIIBO_SET_READONLY, &off, 1);

    // Assert
    ASSERT_EQ(enabled.status, HOST_STATUS_OK);
    ASSERT(after_enable);
    ASSERT_EQ(disabled.status, HOST_STATUS_OK);
    ASSERT(!fixture.amiibo.readonly);
    return true;
}

static bool test_set_readonly_rejects_a_bad_payload(void) {
    // Arrange
    load_dump(AMIIBO_V3_SIZE);
    const uint8_t bad = 2;

    // Act
    host_response_t too_big = run(HOST_CMD_AMIIBO_SET_READONLY, &bad, 1);
    host_response_t empty = run(HOST_CMD_AMIIBO_SET_READONLY, NULL, 0);

    // Assert
    ASSERT_EQ(too_big.status, HOST_STATUS_INVALID_PARAMS);
    ASSERT_EQ(empty.status, HOST_STATUS_INVALID_PARAMS);
    ASSERT(!fixture.amiibo.readonly);
    return true;
}

TEST_MAIN_BEGIN("host_amiibo_read")
    RUN_TEST(test_read_reports_the_size_and_the_chunk_size);
    RUN_TEST(test_read_without_an_amiibo_is_an_amiibo_error);
    RUN_TEST(test_chunks_reassemble_the_whole_dump);
    RUN_TEST(test_the_last_chunk_of_a_v2_dump_is_short);
    RUN_TEST(test_a_chunk_past_the_end_is_invalid);
    RUN_TEST(test_a_chunk_shows_changes_made_to_the_stored_dump);
    RUN_TEST(test_set_readonly_toggles_the_store_flag);
    RUN_TEST(test_set_readonly_rejects_a_bad_payload);
TEST_MAIN_END()
