#include "test_framework.h"
#include "test_write_support.h"

#include "nfc/nfc_session.h"

typedef struct {
    int started;
    int finished;
    int succeeded;
} listener_log_t;

static amiibo_store_t store;
static nfc_session_t session;
static uint8_t original[AMIIBO_V3_SIZE];
static listener_log_t log_of_calls;

static void on_write_started(void *context) {
    (void)context;
    log_of_calls.started++;
}

static void on_write_finished(void *context, bool succeeded) {
    (void)context;
    log_of_calls.finished++;
    log_of_calls.succeeded = succeeded;
}

static void load_session(void) {
    for (size_t index = 0; index < sizeof(original); index++) {
        original[index] = (uint8_t)(index * 7 + 3);
    }
    memset(&log_of_calls, 0, sizeof(log_of_calls));
    amiibo_store_init(&store);
    amiibo_store_load(&store, original, sizeof(original));
    nfc_session_init(&session, &store);
    const nfc_session_listener_t listener = {NULL, on_write_started, on_write_finished, NULL};
    nfc_session_set_listener(&session, &listener);
}

static void feed(const uint8_t *data, size_t length) {
    for (size_t index = 0; index < write_piece_count(length); index++) {
        uint8_t piece[WRITE_PIECE_SIZE];

        write_piece_at(data, length, index, piece);
        nfc_session_add_write_piece(&session, piece, sizeof(piece));
    }
}

static void feed_slot_write(void) {
    uint8_t data[64];

    feed(data, build_slot_write(data, original));
}

static void feed_app_data_write(void) {
    uint8_t data[64];

    feed(data, build_app_data_write(data, original));
}

static uint8_t poll_status(void) {
    uint8_t reply[NFC_POLL_REPLY_SIZE];

    nfc_session_poll(&session, reply, sizeof(reply));
    return reply[0];
}

static bool test_the_full_write_sequence_updates_the_dump_and_walks_the_statuses(void) {
    // Arrange
    load_session();
    nfc_session_commit_write(&session);
    feed_slot_write();

    // Act
    bool slots = nfc_session_commit_slots(&session);
    uint8_t after_slots = poll_status();
    feed_app_data_write();
    bool finished = nfc_session_finish_write(&session);
    uint8_t after_write = poll_status();

    // Assert
    ASSERT(slots);
    ASSERT(finished);
    ASSERT_EQ(after_slots, 0x16);
    ASSERT_EQ(after_write, 0x05);
    ASSERT_EQ(store.data[0x248], 0x33);
    ASSERT_EQ(store.data[0x404], 0x44);
    ASSERT_MEM_EQ(&store.data[0x10], ((const uint8_t[]){0xA5, 0x83, 0xF6, 0x00}), 4);
    ASSERT_EQ(store.data[0x14], 0x11);
    ASSERT_EQ(log_of_calls.started, 1);
    ASSERT_EQ(log_of_calls.finished, 1);
    ASSERT(log_of_calls.succeeded);
    return true;
}

static bool test_the_page_three_read_between_the_writes_does_not_cancel_the_second(void) {
    // Arrange
    load_session();
    feed_slot_write();
    nfc_session_commit_slots(&session);
    uint8_t pre_read[19] = {0xD0, 0x07};
    memcpy(&pre_read[2], original, AMIIBO_UID_SIZE);
    pre_read[9] = 0x01;
    pre_read[10] = 0x01;
    pre_read[11] = 0x03;
    pre_read[12] = 0x03;
    nfc_session_start_read(&session, pre_read, sizeof(pre_read));
    feed_app_data_write();

    // Act
    bool finished = nfc_session_finish_write(&session);

    // Assert
    ASSERT(finished);
    ASSERT_EQ(poll_status(), 0x05);
    ASSERT_EQ(store.data[0x14], 0x11);
    return true;
}

static bool test_the_page_three_pre_read_serves_exactly_that_page(void) {
    // Arrange
    load_session();
    uint8_t pre_read[19] = {0xD0, 0x07};
    pre_read[9] = 0x01;
    pre_read[10] = 0x01;
    pre_read[11] = 0x03;
    pre_read[12] = 0x03;

    // Act
    bool started = nfc_session_start_read(&session, pre_read, sizeof(pre_read));

    // Assert
    ASSERT(started);
    ASSERT_EQ(session.buffer_length, 19 + NFC_BLOCK_SIZE + 9 + 4);
    ASSERT_MEM_EQ(&session.buffer[19 + NFC_BLOCK_SIZE + 9], &original[12], 4);
    return true;
}

static bool test_a_read_only_amiibo_refuses_the_write_and_keeps_its_data(void) {
    // Arrange
    load_session();
    store.readonly = true;
    feed_slot_write();

    // Act
    bool slots = nfc_session_commit_slots(&session);
    feed_app_data_write();
    bool finished = nfc_session_finish_write(&session);

    // Assert
    ASSERT(!slots);
    ASSERT(!finished);
    ASSERT_EQ(poll_status(), 0x07);
    ASSERT_MEM_EQ(store.data, original, sizeof(original));
    ASSERT_EQ(log_of_calls.finished, 1);
    ASSERT(!log_of_calls.succeeded);
    return true;
}

static bool test_app_data_without_the_slot_step_is_refused(void) {
    // Arrange
    load_session();
    feed_app_data_write();

    // Act
    bool finished = nfc_session_finish_write(&session);

    // Assert
    ASSERT(!finished);
    ASSERT_EQ(poll_status(), 0x07);
    ASSERT_MEM_EQ(store.data, original, sizeof(original));
    return true;
}

static bool test_ending_the_session_discards_a_partial_write(void) {
    // Arrange
    load_session();
    feed_slot_write();
    nfc_session_commit_slots(&session);
    feed_app_data_write();
    nfc_session_end(&session);

    // Act
    bool finished = nfc_session_finish_write(&session);

    // Assert
    ASSERT(!finished);
    ASSERT_EQ(store.data[0x14], original[0x14]);
    return true;
}

static bool test_each_write_step_raises_an_event(void) {
    // Arrange
    load_session();
    feed_slot_write();
    nfc_session_commit_slots(&session);
    nfc_session_tick(&session, NFC_PHASE_DELAY_MS);
    uint8_t after_slots = nfc_session_event_counter(&session);
    feed_app_data_write();

    // Act
    nfc_session_finish_write(&session);
    nfc_session_tick(&session, NFC_PHASE_DELAY_MS);

    // Assert
    ASSERT_EQ(after_slots, 1);
    ASSERT_EQ(nfc_session_event_counter(&session), 2);
    return true;
}

TEST_MAIN_BEGIN("nfc_session_write")
    RUN_TEST(test_the_full_write_sequence_updates_the_dump_and_walks_the_statuses);
    RUN_TEST(test_the_page_three_read_between_the_writes_does_not_cancel_the_second);
    RUN_TEST(test_the_page_three_pre_read_serves_exactly_that_page);
    RUN_TEST(test_a_read_only_amiibo_refuses_the_write_and_keeps_its_data);
    RUN_TEST(test_app_data_without_the_slot_step_is_refused);
    RUN_TEST(test_ending_the_session_discards_a_partial_write);
    RUN_TEST(test_each_write_step_raises_an_event);
TEST_MAIN_END()
