#include "test_framework.h"

#include "protocol/command_router.h"

static size_t echo_context_handler(void *context,
                                   const command_request_t *request,
                                   uint8_t *payload,
                                   size_t capacity) {
    (void)request;
    (void)capacity;
    payload[0] = *(const uint8_t *)context;
    return 1;
}

static size_t constant_handler(void *context,
                               const command_request_t *request,
                               uint8_t *payload,
                               size_t capacity) {
    (void)context;
    (void)request;
    (void)capacity;
    payload[0] = 0xAA;
    return 1;
}

static bool test_dispatches_to_the_matching_route(void) {
    // Arrange
    uint8_t context_value = 0x42;
    const command_route_t routes[] = {
        {0x07, 0x01, constant_handler, NULL},
        {0x02, 0x04, echo_context_handler, &context_value},
    };
    const command_router_t router = {routes, 2};
    const command_request_t request = {.command = 0x02, .subcommand = 0x04};
    uint8_t payload[4];
    size_t payload_length = 0;

    // Act
    command_router_status_t status =
        command_router_dispatch(&router, &request, payload, sizeof(payload), &payload_length);

    // Assert
    ASSERT_EQ(status, COMMAND_ROUTER_HANDLED);
    ASSERT_EQ(payload_length, 1);
    ASSERT_EQ(payload[0], 0x42);
    return true;
}

static bool test_unknown_subcommand_is_not_handled(void) {
    // Arrange
    const command_route_t routes[] = {{0x07, 0x01, constant_handler, NULL}};
    const command_router_t router = {routes, 1};
    const command_request_t request = {.command = 0x07, .subcommand = 0x02};
    uint8_t payload[4];
    size_t payload_length = 99;

    // Act
    command_router_status_t status =
        command_router_dispatch(&router, &request, payload, sizeof(payload), &payload_length);

    // Assert
    ASSERT_EQ(status, COMMAND_ROUTER_UNKNOWN);
    ASSERT_EQ(payload_length, 99);
    return true;
}

static bool test_empty_router_handles_nothing(void) {
    // Arrange
    const command_router_t router = {NULL, 0};
    const command_request_t request = {.command = 0x07, .subcommand = 0x01};
    uint8_t payload[4];
    size_t payload_length = 0;

    // Act
    command_router_status_t status =
        command_router_dispatch(&router, &request, payload, sizeof(payload), &payload_length);

    // Assert
    ASSERT_EQ(status, COMMAND_ROUTER_UNKNOWN);
    return true;
}

TEST_MAIN_BEGIN("command_router")
    RUN_TEST(test_dispatches_to_the_matching_route);
    RUN_TEST(test_unknown_subcommand_is_not_handled);
    RUN_TEST(test_empty_router_handles_nothing);
TEST_MAIN_END()
