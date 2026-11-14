#include "test_framework.h"

#include "controller/identity.h"
#include "protocol/command_set.h"
#include "storage/ram_pairing_store.h"

static const uint8_t REGION_DATA[] = {0x01, 0x02, 0x03, 0x04};
static const uint8_t STATUS_PAYLOAD[] = {0x00};

static const memory_region_t REGIONS[] = {{0x1000, sizeof(REGION_DATA), REGION_DATA}};
static const static_reply_t REPLIES[] = {
    {0x07, 0x01, STATUS_PAYLOAD, sizeof(STATUS_PAYLOAD)},
    {0x09, 0x07, NULL, 0},
};
static const controller_identity_t IDENTITY = {REGIONS, 1, REPLIES, 2};

static const uint8_t LOCAL_ADDRESS[PAIRING_ADDRESS_SIZE] = {0x0E, 0x75, 0xDE, 0x55, 0xE2, 0x98};

static ram_pairing_store_t RAM_STORE;
static pairing_t PAIRING;

static bool init_set(command_set_t *set) {
    ram_pairing_store_init(&RAM_STORE);
    pairing_init(&PAIRING, &RAM_STORE.store, LOCAL_ADDRESS);
    return command_set_init(set, &IDENTITY, &PAIRING);
}

static command_request_t memory_read_request(const uint8_t *payload) {
    command_request_t request = {
        .command = 0x02, .subcommand = 0x04, .payload = payload, .payload_length = 8,
    };
    return request;
}

static bool test_static_reply_returns_its_payload(void) {
    // Arrange
    command_set_t set;
    init_set(&set);
    const command_request_t request = {.command = 0x07, .subcommand = 0x01};
    uint8_t payload[8];
    size_t payload_length = 0;

    // Act
    command_router_status_t status =
        command_router_dispatch(&set.router, &request, payload, sizeof(payload), &payload_length);

    // Assert
    ASSERT_EQ(status, COMMAND_ROUTER_HANDLED);
    ASSERT_EQ(payload_length, 1);
    ASSERT_EQ(payload[0], 0x00);
    return true;
}

static bool test_static_reply_may_be_empty(void) {
    // Arrange
    command_set_t set;
    init_set(&set);
    const command_request_t request = {.command = 0x09, .subcommand = 0x07};
    uint8_t payload[8];
    size_t payload_length = 99;

    // Act
    command_router_status_t status =
        command_router_dispatch(&set.router, &request, payload, sizeof(payload), &payload_length);

    // Assert
    ASSERT_EQ(status, COMMAND_ROUTER_HANDLED);
    ASSERT_EQ(payload_length, 0);
    return true;
}

static bool test_memory_read_inside_a_region(void) {
    // Arrange
    command_set_t set;
    init_set(&set);
    const uint8_t request_payload[] = {0x04, 0x7E, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00};
    const command_request_t request = memory_read_request(request_payload);
    const uint8_t expected[] = {0x04, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04};
    uint8_t payload[32];
    size_t payload_length = 0;

    // Act
    command_router_dispatch(&set.router, &request, payload, sizeof(payload), &payload_length);

    // Assert
    ASSERT_EQ(payload_length, sizeof(expected));
    ASSERT_MEM_EQ(payload, expected, sizeof(expected));
    return true;
}

static bool test_memory_read_outside_a_region_is_erased_flash(void) {
    // Arrange
    command_set_t set;
    init_set(&set);
    const uint8_t request_payload[] = {0x06, 0x7E, 0x00, 0x00, 0x02, 0x10, 0x00, 0x00};
    const command_request_t request = memory_read_request(request_payload);
    const uint8_t expected_data[] = {0x03, 0x04, 0xFF, 0xFF, 0xFF, 0xFF};
    uint8_t payload[32];
    size_t payload_length = 0;

    // Act
    command_router_dispatch(&set.router, &request, payload, sizeof(payload), &payload_length);

    // Assert
    ASSERT_EQ(payload_length, 8 + sizeof(expected_data));
    ASSERT_MEM_EQ(&payload[8], expected_data, sizeof(expected_data));
    return true;
}

static bool test_memory_read_with_a_truncated_request_gives_no_reply(void) {
    // Arrange
    command_set_t set;
    init_set(&set);
    const uint8_t request_payload[] = {0x04, 0x7E, 0x00};
    command_request_t request = memory_read_request(request_payload);
    request.payload_length = sizeof(request_payload);
    uint8_t payload[32];
    size_t payload_length = 99;

    // Act
    command_router_dispatch(&set.router, &request, payload, sizeof(payload), &payload_length);

    // Assert
    ASSERT_EQ(payload_length, 0);
    return true;
}

static bool test_memory_read_larger_than_the_buffer_gives_no_reply(void) {
    // Arrange
    command_set_t set;
    init_set(&set);
    const uint8_t request_payload[] = {0x40, 0x7E, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00};
    const command_request_t request = memory_read_request(request_payload);
    uint8_t payload[16];
    size_t payload_length = 99;

    // Act
    command_router_dispatch(&set.router, &request, payload, sizeof(payload), &payload_length);

    // Assert
    ASSERT_EQ(payload_length, 0);
    return true;
}

static bool test_unknown_command_is_not_handled(void) {
    // Arrange
    command_set_t set;
    init_set(&set);
    const command_request_t request = {.command = 0x7F, .subcommand = 0x7F};
    uint8_t payload[8];
    size_t payload_length = 0;

    // Act
    command_router_status_t status =
        command_router_dispatch(&set.router, &request, payload, sizeof(payload), &payload_length);

    // Assert
    ASSERT_EQ(status, COMMAND_ROUTER_UNKNOWN);
    return true;
}

static bool test_init_fails_when_there_are_too_many_replies(void) {
    // Arrange
    static static_reply_t many[COMMAND_SET_MAX_ROUTES + 1];
    for (size_t index = 0; index < COMMAND_SET_MAX_ROUTES + 1; index++) {
        many[index].command = (uint8_t)index;
        many[index].subcommand = 0x01;
    }
    const controller_identity_t identity = {REGIONS, 1, many, COMMAND_SET_MAX_ROUTES + 1};
    command_set_t set;

    // Act
    ram_pairing_store_init(&RAM_STORE);
    pairing_init(&PAIRING, &RAM_STORE.store, LOCAL_ADDRESS);
    bool initialised = command_set_init(&set, &identity, &PAIRING);

    // Assert
    ASSERT(!initialised);
    return true;
}

TEST_MAIN_BEGIN("command_set")
    RUN_TEST(test_static_reply_returns_its_payload);
    RUN_TEST(test_static_reply_may_be_empty);
    RUN_TEST(test_memory_read_inside_a_region);
    RUN_TEST(test_memory_read_outside_a_region_is_erased_flash);
    RUN_TEST(test_memory_read_with_a_truncated_request_gives_no_reply);
    RUN_TEST(test_memory_read_larger_than_the_buffer_gives_no_reply);
    RUN_TEST(test_unknown_command_is_not_handled);
    RUN_TEST(test_init_fails_when_there_are_too_many_replies);
TEST_MAIN_END()
