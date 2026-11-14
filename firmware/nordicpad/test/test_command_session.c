#include "test_framework.h"

#include "controller/identity.h"
#include "protocol/command_session.h"
#include "storage/ram_pairing_store.h"

#define PREFIX_SIZE 4

static const uint8_t STATUS_PAYLOAD[] = {0x00};
static const static_reply_t REPLIES[] = {{0x07, 0x01, STATUS_PAYLOAD, sizeof(STATUS_PAYLOAD)}};
static const controller_identity_t IDENTITY = {NULL, 0, REPLIES, 1};
static const uint8_t ADDRESS[PAIRING_ADDRESS_SIZE] = {0};

typedef struct {
    ram_pairing_store_t ram_store;
    pairing_t pairing;
    command_set_t set;
    command_session_t session;
} fixture_t;

static void setup(fixture_t *fixture) {
    ram_pairing_store_init(&fixture->ram_store);
    pairing_init(&fixture->pairing, &fixture->ram_store.store, ADDRESS);
    command_set_init(&fixture->set, &IDENTITY, &fixture->pairing);
    command_session_init(&fixture->session, &fixture->set, PREFIX_SIZE);
}

static bool test_known_command_is_answered_with_a_reply_frame(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    const uint8_t write[] = {0xDE, 0xAD, 0xBE, 0xEF, 0x07, 0x91, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00};
    const uint8_t expected[] = {0x07, 0x01, 0x01, 0x01, 0x10, 0x78, 0x00, 0x00, 0x00};
    uint8_t reply[64];
    command_outcome_t outcome;

    // Act
    size_t length = command_session_handle(&fixture.session, write, sizeof(write), reply, sizeof(reply), &outcome);

    // Assert
    ASSERT_EQ(outcome.status, COMMAND_OUTCOME_REPLIED);
    ASSERT_EQ(length, sizeof(expected));
    ASSERT_MEM_EQ(reply, expected, length);
    return true;
}

static bool test_basic_prefix_is_accepted_when_the_profile_prefix_does_not_fit(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t write[COMMAND_BASIC_PREFIX_SIZE + COMMAND_HEADER_SIZE] = {0};
    write[COMMAND_BASIC_PREFIX_SIZE] = 0x07;
    write[COMMAND_BASIC_PREFIX_SIZE + 1] = 0x91;
    write[COMMAND_BASIC_PREFIX_SIZE + 2] = 0x01;
    write[COMMAND_BASIC_PREFIX_SIZE + 3] = 0x01;
    fixture.session.prefix_size = 33;
    uint8_t reply[64];
    command_outcome_t outcome;

    // Act
    size_t length = command_session_handle(&fixture.session, write, sizeof(write), reply, sizeof(reply), &outcome);

    // Assert
    ASSERT_EQ(outcome.status, COMMAND_OUTCOME_REPLIED);
    ASSERT(length > 0);
    return true;
}

static bool test_unknown_command_is_reported_without_a_reply(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    const uint8_t write[] = {0x00, 0x00, 0x00, 0x00, 0x7F, 0x91, 0x01, 0x7E, 0x00, 0x00, 0x00, 0x00};
    uint8_t reply[64];
    command_outcome_t outcome;

    // Act
    size_t length = command_session_handle(&fixture.session, write, sizeof(write), reply, sizeof(reply), &outcome);

    // Assert
    ASSERT_EQ(length, 0);
    ASSERT_EQ(outcome.status, COMMAND_OUTCOME_UNKNOWN);
    ASSERT_EQ(outcome.command, 0x7F);
    ASSERT_EQ(outcome.subcommand, 0x7E);
    return true;
}

static bool test_malformed_write_is_reported(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    const uint8_t write[] = {0x00, 0x01};
    uint8_t reply[64];
    command_outcome_t outcome;

    // Act
    size_t length = command_session_handle(&fixture.session, write, sizeof(write), reply, sizeof(reply), &outcome);

    // Assert
    ASSERT_EQ(length, 0);
    ASSERT_EQ(outcome.status, COMMAND_OUTCOME_MALFORMED);
    return true;
}

static bool test_reply_larger_than_the_output_is_reported(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    const uint8_t write[] = {0x00, 0x00, 0x00, 0x00, 0x07, 0x91, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00};
    uint8_t reply[4];
    command_outcome_t outcome;

    // Act
    size_t length = command_session_handle(&fixture.session, write, sizeof(write), reply, sizeof(reply), &outcome);

    // Assert
    ASSERT_EQ(length, 0);
    ASSERT_EQ(outcome.status, COMMAND_OUTCOME_REPLY_TOO_LARGE);
    return true;
}

TEST_MAIN_BEGIN("command_session")
    RUN_TEST(test_known_command_is_answered_with_a_reply_frame);
    RUN_TEST(test_basic_prefix_is_accepted_when_the_profile_prefix_does_not_fit);
    RUN_TEST(test_unknown_command_is_reported_without_a_reply);
    RUN_TEST(test_malformed_write_is_reported);
    RUN_TEST(test_reply_larger_than_the_output_is_reported);
TEST_MAIN_END()
