#include "test_framework.h"

#include "controller/identity.h"
#include "protocol/command_set.h"
#include "storage/ram_pairing_store.h"

#define KEY_SIZE 16

static const uint8_t LOCAL_ADDRESS[PAIRING_ADDRESS_SIZE] = {0x0E, 0x75, 0xDE, 0x55, 0xE2, 0x98};

static const uint8_t HOST_ADDRESSES_REQUEST[] = {0x00, 0x02, 0xFD, 0xC4, 0xD0, 0x55, 0xE2,
                                                 0x98, 0xFC, 0xC4, 0xD0, 0x55, 0xE2, 0x98};
static const uint8_t HOST_ADDRESSES_REPLY[] = {0x01, 0x04, 0x01, 0x0E, 0x75, 0xDE, 0x55, 0xE2, 0x98};

static const uint8_t KEY_EXCHANGE_REQUEST[] = {0x00, 0xE6, 0x20, 0x9A, 0x9A, 0x5D, 0xD3, 0x27, 0xF7,
                                               0xD4, 0x0A, 0xB8, 0x04, 0xB9, 0x2A, 0x74, 0x0F};
static const uint8_t KEY_EXCHANGE_REPLY[] = {0x01, 0x5C, 0xF6, 0xEE, 0x79, 0x2C, 0xDF, 0x05, 0xE1,
                                             0xBA, 0x2B, 0x63, 0x25, 0xC4, 0x1A, 0x5F, 0x10};

static const uint8_t CHALLENGE_REQUEST[] = {0x00, 0xAB, 0x85, 0xBB, 0x0C, 0x8F, 0xF8, 0x97, 0xF6,
                                            0x9E, 0xEA, 0xEB, 0x0A, 0x95, 0x78, 0x21, 0xAD};
static const uint8_t CHALLENGE_REPLY[] = {0x01, 0x11, 0xF7, 0x01, 0x94, 0xC2, 0x16, 0x0E, 0xA5,
                                          0x19, 0x0C, 0xF4, 0xD5, 0x34, 0x8A, 0x58, 0xBF};

static const uint8_t FINALISE_REQUEST[] = {0x00};
static const uint8_t FINALISE_REPLY[] = {0x01};

static const uint8_t EXPECTED_LINK_KEY[KEY_SIZE] = {0xBA, 0xD6, 0x74, 0xE3, 0x71, 0x0C, 0x22, 0x16,
                                                    0x6E, 0x21, 0xDB, 0x21, 0x7D, 0x30, 0x2B, 0x1F};

static const controller_identity_t EMPTY_IDENTITY = {NULL, 0, NULL, 0};

typedef struct {
    ram_pairing_store_t ram_store;
    pairing_t pairing;
    command_set_t set;
} fixture_t;

static void setup(fixture_t *fixture) {
    ram_pairing_store_init(&fixture->ram_store);
    pairing_init(&fixture->pairing, &fixture->ram_store.store, LOCAL_ADDRESS);
    command_set_init(&fixture->set, &EMPTY_IDENTITY, &fixture->pairing);
}

static size_t send(fixture_t *fixture,
                   uint8_t subcommand,
                   const uint8_t *request_payload,
                   size_t request_length,
                   uint8_t *reply) {
    const command_request_t request = {
        .command = 0x15,
        .subcommand = subcommand,
        .payload = request_payload,
        .payload_length = request_length,
    };
    size_t reply_length = 0;

    command_router_dispatch(&fixture->set.router, &request, reply, 64, &reply_length);
    return reply_length;
}

#define SEND(fixture, subcommand, request, reply) \
    send(fixture, subcommand, request, sizeof(request), reply)

static bool test_host_addresses_reply_with_the_local_address(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t reply[64];

    // Act
    size_t length = SEND(&fixture, 0x01, HOST_ADDRESSES_REQUEST, reply);

    // Assert
    ASSERT_EQ(length, sizeof(HOST_ADDRESSES_REPLY));
    ASSERT_MEM_EQ(reply, HOST_ADDRESSES_REPLY, length);
    return true;
}

static bool test_key_exchange_reply_carries_the_controller_key(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t reply[64];

    // Act
    size_t length = SEND(&fixture, 0x04, KEY_EXCHANGE_REQUEST, reply);

    // Assert
    ASSERT_EQ(length, sizeof(KEY_EXCHANGE_REPLY));
    ASSERT_MEM_EQ(reply, KEY_EXCHANGE_REPLY, length);
    return true;
}

static bool test_challenge_reply_proves_knowledge_of_the_link_key(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t reply[64];
    SEND(&fixture, 0x04, KEY_EXCHANGE_REQUEST, reply);

    // Act
    size_t length = SEND(&fixture, 0x02, CHALLENGE_REQUEST, reply);

    // Assert
    ASSERT_EQ(length, sizeof(CHALLENGE_REPLY));
    ASSERT_MEM_EQ(reply, CHALLENGE_REPLY, length);
    return true;
}

static bool test_challenge_without_a_key_exchange_gets_no_reply(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t reply[64];

    // Act
    size_t length = SEND(&fixture, 0x02, CHALLENGE_REQUEST, reply);

    // Assert
    ASSERT_EQ(length, 0);
    return true;
}

static bool test_finalise_stores_the_link_key(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t reply[64];
    uint8_t link_key[KEY_SIZE];
    SEND(&fixture, 0x04, KEY_EXCHANGE_REQUEST, reply);
    SEND(&fixture, 0x02, CHALLENGE_REQUEST, reply);

    // Act
    size_t length = SEND(&fixture, 0x03, FINALISE_REQUEST, reply);

    // Assert
    ASSERT_EQ(length, sizeof(FINALISE_REPLY));
    ASSERT_MEM_EQ(reply, FINALISE_REPLY, length);
    ASSERT(pairing_get_link_key(&fixture.pairing, link_key));
    ASSERT_MEM_EQ(link_key, EXPECTED_LINK_KEY, KEY_SIZE);
    ASSERT(fixture.ram_store.occupied);
    return true;
}

static bool test_unfinished_pairing_leaves_no_link_key(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t reply[64];
    uint8_t link_key[KEY_SIZE];

    // Act
    SEND(&fixture, 0x04, KEY_EXCHANGE_REQUEST, reply);
    SEND(&fixture, 0x02, CHALLENGE_REQUEST, reply);

    // Assert
    ASSERT(!pairing_get_link_key(&fixture.pairing, link_key));
    ASSERT(!fixture.ram_store.occupied);
    return true;
}

static bool test_finalise_without_a_key_exchange_changes_nothing(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t reply[64];

    // Act
    size_t length = SEND(&fixture, 0x03, FINALISE_REQUEST, reply);

    // Assert
    ASSERT_EQ(length, 0);
    ASSERT(!fixture.ram_store.occupied);
    return true;
}

static bool test_stored_link_key_survives_a_restart(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t reply[64];
    uint8_t link_key[KEY_SIZE];
    SEND(&fixture, 0x04, KEY_EXCHANGE_REQUEST, reply);
    SEND(&fixture, 0x03, FINALISE_REQUEST, reply);
    pairing_t restarted;

    // Act
    pairing_init(&restarted, &fixture.ram_store.store, LOCAL_ADDRESS);

    // Assert
    ASSERT(pairing_get_link_key(&restarted, link_key));
    ASSERT_MEM_EQ(link_key, EXPECTED_LINK_KEY, KEY_SIZE);
    return true;
}

static bool test_new_pairing_does_not_replace_the_key_until_finalised(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t reply[64];
    uint8_t link_key[KEY_SIZE];
    SEND(&fixture, 0x04, KEY_EXCHANGE_REQUEST, reply);
    SEND(&fixture, 0x03, FINALISE_REQUEST, reply);
    uint8_t other_host_key[sizeof(KEY_EXCHANGE_REQUEST)] = {0};

    // Act
    SEND(&fixture, 0x04, other_host_key, reply);

    // Assert
    ASSERT(pairing_get_link_key(&fixture.pairing, link_key));
    ASSERT_MEM_EQ(link_key, EXPECTED_LINK_KEY, KEY_SIZE);
    return true;
}

static bool test_short_key_request_gets_no_reply(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t reply[64];
    const uint8_t short_request[] = {0x00, 0x01, 0x02};

    // Act
    size_t length = SEND(&fixture, 0x04, short_request, reply);

    // Assert
    ASSERT_EQ(length, 0);
    return true;
}

static void run_full_pairing(fixture_t *fixture) {
    uint8_t reply[64];
    SEND(fixture, 0x01, HOST_ADDRESSES_REQUEST, reply);
    SEND(fixture, 0x04, KEY_EXCHANGE_REQUEST, reply);
    SEND(fixture, 0x02, CHALLENGE_REQUEST, reply);
    SEND(fixture, 0x03, FINALISE_REQUEST, reply);
}

static bool test_finalise_stores_the_console_address(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t host_address[PAIRING_ADDRESS_SIZE];
    const uint8_t expected[PAIRING_ADDRESS_SIZE] = {0xFD, 0xC4, 0xD0, 0x55, 0xE2, 0x98};

    // Act
    run_full_pairing(&fixture);
    bool known = pairing_get_host_address(&fixture.pairing, host_address);

    // Assert
    ASSERT(known);
    ASSERT_MEM_EQ(host_address, expected, PAIRING_ADDRESS_SIZE);
    return true;
}

static bool test_console_address_is_unknown_before_pairing_finishes(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    uint8_t reply[64];
    uint8_t host_address[PAIRING_ADDRESS_SIZE];

    // Act
    SEND(&fixture, 0x01, HOST_ADDRESSES_REQUEST, reply);
    bool known = pairing_get_host_address(&fixture.pairing, host_address);

    // Assert
    ASSERT(!known);
    return true;
}

static bool test_console_address_survives_a_restart(void) {
    // Arrange
    fixture_t fixture;
    setup(&fixture);
    run_full_pairing(&fixture);
    pairing_t restarted;
    uint8_t host_address[PAIRING_ADDRESS_SIZE];
    const uint8_t expected[PAIRING_ADDRESS_SIZE] = {0xFD, 0xC4, 0xD0, 0x55, 0xE2, 0x98};

    // Act
    pairing_init(&restarted, &fixture.ram_store.store, LOCAL_ADDRESS);
    bool known = pairing_get_host_address(&restarted, host_address);

    // Assert
    ASSERT(known);
    ASSERT_MEM_EQ(host_address, expected, PAIRING_ADDRESS_SIZE);
    return true;
}

TEST_MAIN_BEGIN("pairing")
    RUN_TEST(test_finalise_stores_the_console_address);
    RUN_TEST(test_console_address_is_unknown_before_pairing_finishes);
    RUN_TEST(test_console_address_survives_a_restart);
    RUN_TEST(test_host_addresses_reply_with_the_local_address);
    RUN_TEST(test_key_exchange_reply_carries_the_controller_key);
    RUN_TEST(test_challenge_reply_proves_knowledge_of_the_link_key);
    RUN_TEST(test_challenge_without_a_key_exchange_gets_no_reply);
    RUN_TEST(test_finalise_stores_the_link_key);
    RUN_TEST(test_unfinished_pairing_leaves_no_link_key);
    RUN_TEST(test_finalise_without_a_key_exchange_changes_nothing);
    RUN_TEST(test_stored_link_key_survives_a_restart);
    RUN_TEST(test_new_pairing_does_not_replace_the_key_until_finalised);
    RUN_TEST(test_short_key_request_gets_no_reply);
TEST_MAIN_END()
