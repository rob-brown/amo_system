#include "test_framework.h"

#include "nfc/nfc_session.h"

static const uint8_t THREE_RANGE_START[] = {
    0xD0, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x03, 0x00, 0x3B, 0x3C, 0x77, 0x78, 0x86, 0x00, 0x00,
};

static const uint8_t FIRST_CHUNK[] = {0x00, 0x00};

typedef struct {
    amiibo_store_t amiibo;
    nfc_session_t session;
    uint8_t dump[AMIIBO_V2_SIZE];
} fixture_t;

static fixture_t fixture;

static void load_fixture(void) {
    for (size_t index = 0; index < sizeof(fixture.dump); index++) {
        fixture.dump[index] = (uint8_t)(index * 5 + 1);
    }
    amiibo_store_init(&fixture.amiibo);
    amiibo_store_load(&fixture.amiibo, fixture.dump, sizeof(fixture.dump));
    nfc_session_init(&fixture.session, &fixture.amiibo);
}

static void load_empty_fixture(void) {
    amiibo_store_init(&fixture.amiibo);
    nfc_session_init(&fixture.session, &fixture.amiibo);
}

static bool test_poll_without_a_tag_reports_none(void) {
    // Arrange
    load_empty_fixture();
    uint8_t reply[NFC_POLL_REPLY_SIZE];

    // Act
    size_t length = nfc_session_poll(&fixture.session, reply, sizeof(reply));

    // Assert
    ASSERT_EQ(length, NFC_POLL_REPLY_SIZE);
    ASSERT_EQ(reply[0], 0x00);
    return true;
}

static bool test_poll_with_a_tag_reports_found_and_the_uid(void) {
    // Arrange
    load_fixture();
    uint8_t reply[NFC_POLL_REPLY_SIZE];

    // Act
    nfc_session_poll(&fixture.session, reply, sizeof(reply));

    // Assert
    ASSERT_EQ(reply[0], 0x09);
    ASSERT_MEM_EQ(&reply[4], ((const uint8_t[]){0x01, 0x01, 0x02, 0x00, 0x07}), 5);
    ASSERT_MEM_EQ(&reply[9], ((const uint8_t[]){fixture.dump[0], fixture.dump[1], fixture.dump[2], fixture.dump[4], fixture.dump[5], fixture.dump[6], fixture.dump[7]}), 7);
    return true;
}

static bool test_poll_reports_read_ready_after_start_and_found_after_end(void) {
    // Arrange
    load_fixture();
    uint8_t reply[NFC_POLL_REPLY_SIZE];
    nfc_session_start_read(&fixture.session, THREE_RANGE_START, sizeof(THREE_RANGE_START));

    // Act
    nfc_session_poll(&fixture.session, reply, sizeof(reply));
    uint8_t while_reading = reply[0];
    nfc_session_end(&fixture.session);
    nfc_session_poll(&fixture.session, reply, sizeof(reply));

    // Assert
    ASSERT_EQ(while_reading, 0x04);
    ASSERT_EQ(reply[0], 0x09);
    return true;
}

static bool test_start_without_a_tag_is_refused(void) {
    // Arrange
    load_empty_fixture();

    // Act
    bool started = nfc_session_start_read(&fixture.session, THREE_RANGE_START, sizeof(THREE_RANGE_START));

    // Assert
    ASSERT(!started);
    ASSERT_EQ(fixture.session.state, NFC_STATE_IDLE);
    return true;
}

static int reads_started;

static void count_read_started(void *context) {
    (void)context;
    reads_started++;
}

static bool test_listener_hears_about_each_read_that_starts(void) {
    // Arrange
    load_fixture();
    reads_started = 0;
    const nfc_session_listener_t listener = {count_read_started, NULL};
    nfc_session_set_listener(&fixture.session, &listener);

    // Act
    nfc_session_start_read(&fixture.session, THREE_RANGE_START, sizeof(THREE_RANGE_START));
    nfc_session_end(&fixture.session);
    nfc_session_start_read(&fixture.session, THREE_RANGE_START, sizeof(THREE_RANGE_START));

    // Assert
    ASSERT_EQ(reads_started, 2);
    return true;
}

static bool test_listener_is_silent_when_the_read_is_refused(void) {
    // Arrange
    load_empty_fixture();
    reads_started = 0;
    const nfc_session_listener_t listener = {count_read_started, NULL};
    nfc_session_set_listener(&fixture.session, &listener);

    // Act
    nfc_session_start_read(&fixture.session, THREE_RANGE_START, sizeof(THREE_RANGE_START));

    // Assert
    ASSERT_EQ(reads_started, 0);
    return true;
}

static bool test_read_before_start_returns_nothing(void) {
    // Arrange
    load_fixture();
    uint8_t reply[NFC_READ_REPLY_SIZE];

    // Act
    size_t length = nfc_session_read(&fixture.session, FIRST_CHUNK, sizeof(FIRST_CHUNK), reply, sizeof(reply));

    // Assert
    ASSERT_EQ(length, 0);
    return true;
}

static bool test_buffer_holds_header_block_echo_and_every_requested_page(void) {
    // Arrange
    load_fixture();

    // Act
    bool started = nfc_session_start_read(&fixture.session, THREE_RANGE_START, sizeof(THREE_RANGE_START));

    // Assert
    ASSERT(started);
    ASSERT_EQ(fixture.session.buffer_length, 19 + NFC_BLOCK_SIZE + 9 + AMIIBO_V2_SIZE);
    ASSERT_MEM_EQ(&fixture.session.buffer[19 + NFC_BLOCK_SIZE], &THREE_RANGE_START[10], 9);
    ASSERT_MEM_EQ(&fixture.session.buffer[19 + NFC_BLOCK_SIZE + 9], fixture.dump, AMIIBO_V2_SIZE);
    return true;
}

static bool test_chunks_are_sixty_nine_bytes_and_the_last_is_flagged(void) {
    // Arrange
    load_fixture();
    nfc_session_start_read(&fixture.session, THREE_RANGE_START, sizeof(THREE_RANGE_START));
    uint8_t reply[NFC_READ_REPLY_SIZE];
    size_t total = fixture.session.buffer_length;
    size_t last_offset = (total / NFC_READ_CHUNK_SIZE) * NFC_READ_CHUNK_SIZE;
    uint8_t first_request[] = {0x00, 0x00};
    uint8_t last_request[] = {(uint8_t)(last_offset & 0xFF), (uint8_t)(last_offset >> 8)};

    // Act
    nfc_session_read(&fixture.session, first_request, sizeof(first_request), reply, sizeof(reply));
    uint8_t first_flag = reply[0];
    uint8_t first_length = reply[1];
    nfc_session_read(&fixture.session, last_request, sizeof(last_request), reply, sizeof(reply));

    // Assert
    ASSERT_EQ(first_flag, 0);
    ASSERT_EQ(first_length, NFC_READ_CHUNK_SIZE);
    ASSERT_EQ(reply[0], 1);
    ASSERT_EQ(reply[1], total - last_offset);
    return true;
}

static bool test_read_past_the_end_returns_nothing(void) {
    // Arrange
    load_fixture();
    nfc_session_start_read(&fixture.session, THREE_RANGE_START, sizeof(THREE_RANGE_START));
    uint8_t reply[NFC_READ_REPLY_SIZE];
    uint8_t request[] = {0xFF, 0x7F};

    // Act
    size_t length = nfc_session_read(&fixture.session, request, sizeof(request), reply, sizeof(reply));

    // Assert
    ASSERT_EQ(length, 0);
    return true;
}

static bool test_ranges_beyond_the_dump_are_refused(void) {
    // Arrange
    load_fixture();
    uint8_t request[sizeof(THREE_RANGE_START)];
    memcpy(request, THREE_RANGE_START, sizeof(request));
    request[16] = 0xF0;

    // Act
    bool started = nfc_session_start_read(&fixture.session, request, sizeof(request));

    // Assert
    ASSERT(!started);
    ASSERT_EQ(fixture.session.state, NFC_STATE_IDLE);
    return true;
}

static bool test_truncated_start_request_is_refused(void) {
    // Arrange
    load_fixture();

    // Act
    bool started = nfc_session_start_read(&fixture.session, THREE_RANGE_START, 12);

    // Assert
    ASSERT(!started);
    return true;
}

static const uint8_t FIRST_CONFIGURE[] = {0x00, 0x00, 0x00, 0x2C, 0x01};
static const uint8_t REPEAT_CONFIGURE[] = {0x00, 0xE8, 0x03, 0x2C, 0x01};

typedef struct {
    amiibo_store_t amiibo;
    nfc_session_t session;
    uint8_t dump[AMIIBO_V3_SIZE];
} v3_fixture_t;

static v3_fixture_t v3;

static const uint8_t V3_START_READ[] = {
    0xB8, 0x0B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x04, 0x00, 0x3B, 0x3C, 0x77, 0x78, 0x91, 0xE2, 0xE6,
};

static const uint8_t REGISTRY_REQUEST[] = {
    0xD0, 0x07, 0x04, 0x68, 0x99, 0x5A, 0xAB, 0x1F, 0x90, 0x01, 0x02, 0x00, 0x92, 0x99, 0x01, 0x00, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};

static void load_v3_fixture(void) {
    for (size_t index = 0; index < sizeof(v3.dump); index++) {
        v3.dump[index] = (uint8_t)(index * 3 + 7);
    }
    amiibo_store_init(&v3.amiibo);
    amiibo_store_load(&v3.amiibo, v3.dump, sizeof(v3.dump));
    nfc_session_init(&v3.session, &v3.amiibo);
}

static void run_v3_through_sram(void) {
    load_v3_fixture();
    nfc_session_start_read(&v3.session, V3_START_READ, sizeof(V3_START_READ));
    nfc_session_commit_write(&v3.session);
}

static bool test_v3_read_header_carries_the_v3_flag_and_a_contiguous_uid(void) {
    // Arrange
    load_v3_fixture();

    // Act
    bool started = nfc_session_start_read(&v3.session, V3_START_READ, sizeof(V3_START_READ));

    // Assert
    ASSERT(started);
    ASSERT_MEM_EQ(&v3.session.buffer[8], v3.dump, AMIIBO_UID_SIZE);
    ASSERT_EQ(v3.session.buffer[18], 0x06);
    return true;
}

static bool test_v3_four_range_read_covers_every_requested_page(void) {
    // Arrange
    load_v3_fixture();

    // Act
    nfc_session_start_read(&v3.session, V3_START_READ, sizeof(V3_START_READ));

    // Assert
    ASSERT_EQ(v3.session.buffer_length, 19 + NFC_BLOCK_SIZE + 9 + (0x92 + 5) * 4);
    ASSERT_MEM_EQ(&v3.session.buffer[19 + NFC_BLOCK_SIZE + 9], v3.dump, 0x92 * 4);
    ASSERT_MEM_EQ(&v3.session.buffer[19 + NFC_BLOCK_SIZE + 9 + 0x92 * 4], &v3.dump[0xE2 * 4], 5 * 4);
    return true;
}

static bool test_commit_in_a_fresh_session_serves_the_sram(void) {
    // Arrange
    load_v3_fixture();

    // Act
    bool committed = nfc_session_commit_write(&v3.session);

    // Assert
    ASSERT(committed);
    ASSERT_EQ(v3.session.state, NFC_STATE_SRAM);
    return true;
}

static bool test_commit_on_a_v2_dump_is_refused(void) {
    // Arrange
    load_fixture();
    nfc_session_start_read(&fixture.session, THREE_RANGE_START, sizeof(THREE_RANGE_START));

    // Act
    bool committed = nfc_session_commit_write(&fixture.session);

    // Assert
    ASSERT(!committed);
    ASSERT_EQ(fixture.session.state, NFC_STATE_READING);
    return true;
}

static bool test_commit_exposes_the_sram_after_the_header(void) {
    // Arrange
    run_v3_through_sram();

    // Act
    uint8_t first_byte = v3.session.buffer[0];

    // Assert
    ASSERT_EQ(v3.session.state, NFC_STATE_SRAM);
    ASSERT_EQ(first_byte, 0x18);
    ASSERT_EQ(v3.session.buffer_length, 19 + 64);
    ASSERT_MEM_EQ(&v3.session.buffer[19], &v3.dump[960], 64);
    return true;
}

static bool test_poll_in_the_sram_and_registry_phases_has_no_uid(void) {
    // Arrange
    run_v3_through_sram();
    uint8_t sram_poll[NFC_POLL_REPLY_SIZE];
    uint8_t registry_poll[NFC_POLL_REPLY_SIZE];
    uint8_t zeros[NFC_POLL_REPLY_SIZE - 1] = {0};

    // Act
    nfc_session_poll(&v3.session, sram_poll, sizeof(sram_poll));
    nfc_session_read_registry(&v3.session, REGISTRY_REQUEST, sizeof(REGISTRY_REQUEST));
    nfc_session_poll(&v3.session, registry_poll, sizeof(registry_poll));

    // Assert
    ASSERT_EQ(sram_poll[0], 0x18);
    ASSERT_MEM_EQ(&sram_poll[1], zeros, sizeof(zeros));
    ASSERT_EQ(registry_poll[0], 0x15);
    ASSERT_MEM_EQ(&registry_poll[1], zeros, sizeof(zeros));
    return true;
}

static bool test_registry_read_serves_the_pages_of_the_requested_slot(void) {
    // Arrange
    run_v3_through_sram();

    // Act
    bool read = nfc_session_read_registry(&v3.session, REGISTRY_REQUEST, sizeof(REGISTRY_REQUEST));

    // Assert
    ASSERT(read);
    ASSERT_EQ(v3.session.buffer[0], 0x15);
    ASSERT_EQ(v3.session.buffer_length, 64 + 132);
    ASSERT_MEM_EQ(&v3.session.buffer[64], &v3.dump[584], 32);
    ASSERT_MEM_EQ(&v3.session.buffer[64 + 32], &v3.dump[1024], 100);
    return true;
}

static bool test_registry_read_needs_the_sram_phase_first(void) {
    // Arrange
    load_v3_fixture();
    nfc_session_start_read(&v3.session, V3_START_READ, sizeof(V3_START_READ));

    // Act
    bool read = nfc_session_read_registry(&v3.session, REGISTRY_REQUEST, sizeof(REGISTRY_REQUEST));

    // Assert
    ASSERT(!read);
    return true;
}

static bool test_registry_ranges_beyond_the_dump_are_refused(void) {
    // Arrange
    run_v3_through_sram();
    uint8_t request[sizeof(REGISTRY_REQUEST)];
    memcpy(request, REGISTRY_REQUEST, sizeof(request));
    request[14] = 0x02;

    // Act
    bool read = nfc_session_read_registry(&v3.session, request, sizeof(request));

    // Assert
    ASSERT(!read);
    ASSERT_EQ(v3.session.state, NFC_STATE_SRAM);
    return true;
}

static bool test_each_v3_phase_raises_an_event(void) {
    // Arrange
    run_v3_through_sram();
    nfc_session_tick(&v3.session, NFC_PHASE_DELAY_MS);
    uint8_t after_sram = nfc_session_event_counter(&v3.session);

    // Act
    nfc_session_read_registry(&v3.session, REGISTRY_REQUEST, sizeof(REGISTRY_REQUEST));
    nfc_session_tick(&v3.session, NFC_PHASE_DELAY_MS);

    // Assert
    ASSERT_EQ(after_sram, 1);
    ASSERT_EQ(nfc_session_event_counter(&v3.session), 2);
    return true;
}

static bool test_event_counter_starts_at_zero(void) {
    // Arrange
    load_fixture();

    // Act
    uint8_t counter = nfc_session_event_counter(&fixture.session);

    // Assert
    ASSERT_EQ(counter, 0);
    return true;
}

static bool test_first_configure_raises_an_event_after_about_a_second(void) {
    // Arrange
    load_fixture();
    nfc_session_configure(&fixture.session, FIRST_CONFIGURE, sizeof(FIRST_CONFIGURE));

    // Act
    nfc_session_tick(&fixture.session, NFC_FIRST_CONFIGURE_DELAY_MS - 1);
    uint8_t before = nfc_session_event_counter(&fixture.session);
    nfc_session_tick(&fixture.session, 1);
    uint8_t after = nfc_session_event_counter(&fixture.session);

    // Assert
    ASSERT_EQ(before, 0);
    ASSERT_EQ(after, 1);
    return true;
}

static bool test_repeat_configure_raises_an_event_quickly(void) {
    // Arrange
    load_fixture();
    nfc_session_configure(&fixture.session, REPEAT_CONFIGURE, sizeof(REPEAT_CONFIGURE));

    // Act
    nfc_session_tick(&fixture.session, NFC_REPEAT_CONFIGURE_DELAY_MS);

    // Assert
    ASSERT_EQ(nfc_session_event_counter(&fixture.session), 1);
    return true;
}

static bool test_start_read_raises_an_event_when_the_data_is_ready(void) {
    // Arrange
    load_fixture();
    nfc_session_start_read(&fixture.session, THREE_RANGE_START, sizeof(THREE_RANGE_START));

    // Act
    nfc_session_tick(&fixture.session, NFC_PHASE_DELAY_MS);

    // Assert
    ASSERT_EQ(nfc_session_event_counter(&fixture.session), 1);
    return true;
}

static bool test_no_event_is_raised_without_a_tag(void) {
    // Arrange
    load_empty_fixture();
    nfc_session_configure(&fixture.session, FIRST_CONFIGURE, sizeof(FIRST_CONFIGURE));

    // Act
    nfc_session_tick(&fixture.session, 5000);

    // Assert
    ASSERT_EQ(nfc_session_event_counter(&fixture.session), 0);
    return true;
}

static bool test_loading_an_amiibo_while_the_console_waits_raises_an_event(void) {
    // Arrange
    load_empty_fixture();
    nfc_session_configure(&fixture.session, FIRST_CONFIGURE, sizeof(FIRST_CONFIGURE));
    nfc_session_tick(&fixture.session, 5000);
    for (size_t index = 0; index < sizeof(fixture.dump); index++) {
        fixture.dump[index] = (uint8_t)(index * 5 + 1);
    }

    // Act
    amiibo_store_load(&fixture.amiibo, fixture.dump, sizeof(fixture.dump));
    nfc_session_tick(&fixture.session, NFC_REPEAT_CONFIGURE_DELAY_MS);

    // Assert
    ASSERT_EQ(nfc_session_event_counter(&fixture.session), 1);
    return true;
}

static bool test_replacing_the_amiibo_while_the_console_waits_raises_another_event(void) {
    // Arrange
    load_fixture();
    nfc_session_configure(&fixture.session, REPEAT_CONFIGURE, sizeof(REPEAT_CONFIGURE));
    nfc_session_tick(&fixture.session, NFC_REPEAT_CONFIGURE_DELAY_MS);
    uint8_t before = nfc_session_event_counter(&fixture.session);

    // Act
    amiibo_store_load(&fixture.amiibo, fixture.dump, sizeof(fixture.dump));
    nfc_session_tick(&fixture.session, NFC_REPEAT_CONFIGURE_DELAY_MS);

    // Assert
    ASSERT_EQ(before, 1);
    ASSERT_EQ(nfc_session_event_counter(&fixture.session), 2);
    return true;
}

static bool test_loading_an_amiibo_before_the_console_scans_raises_no_early_event(void) {
    // Arrange
    load_empty_fixture();
    nfc_session_tick(&fixture.session, 1);

    // Act
    amiibo_store_load(&fixture.amiibo, fixture.dump, sizeof(fixture.dump));
    nfc_session_tick(&fixture.session, 5000);

    // Assert
    ASSERT_EQ(nfc_session_event_counter(&fixture.session), 0);
    return true;
}

static bool test_loading_an_amiibo_after_the_scan_ended_raises_no_event(void) {
    // Arrange
    load_empty_fixture();
    nfc_session_configure(&fixture.session, FIRST_CONFIGURE, sizeof(FIRST_CONFIGURE));
    nfc_session_end(&fixture.session);

    // Act
    amiibo_store_load(&fixture.amiibo, fixture.dump, sizeof(fixture.dump));
    nfc_session_tick(&fixture.session, 5000);

    // Assert
    ASSERT_EQ(nfc_session_event_counter(&fixture.session), 0);
    return true;
}

static bool test_clearing_the_amiibo_while_the_console_waits_raises_an_event_and_polls_as_no_tag(void) {
    // Arrange
    load_fixture();
    nfc_session_configure(&fixture.session, REPEAT_CONFIGURE, sizeof(REPEAT_CONFIGURE));
    nfc_session_tick(&fixture.session, NFC_REPEAT_CONFIGURE_DELAY_MS);
    uint8_t reply[NFC_POLL_REPLY_SIZE];

    // Act
    amiibo_store_clear(&fixture.amiibo);
    nfc_session_tick(&fixture.session, 5000);
    nfc_session_poll(&fixture.session, reply, sizeof(reply));

    // Assert
    ASSERT_EQ(nfc_session_event_counter(&fixture.session), 2);
    ASSERT_EQ(reply[0], 0x00);
    return true;
}

static bool test_a_removed_tag_is_reported_lost_once_after_it_was_seen(void) {
    // Arrange
    load_fixture();
    uint8_t reply[NFC_POLL_REPLY_SIZE];
    nfc_session_poll(&fixture.session, reply, sizeof(reply));
    amiibo_store_clear(&fixture.amiibo);

    // Act
    nfc_session_poll(&fixture.session, reply, sizeof(reply));
    uint8_t first_status = reply[0];
    uint8_t first_detail = reply[1];
    nfc_session_poll(&fixture.session, reply, sizeof(reply));

    // Assert
    ASSERT_EQ(first_status, 0x07);
    ASSERT_EQ(first_detail, 0x41);
    ASSERT_EQ(reply[0], 0x00);
    ASSERT_EQ(reply[1], 0x00);
    return true;
}

static bool test_an_upload_in_progress_raises_no_event(void) {
    // Arrange
    load_fixture();
    nfc_session_configure(&fixture.session, REPEAT_CONFIGURE, sizeof(REPEAT_CONFIGURE));
    nfc_session_tick(&fixture.session, NFC_REPEAT_CONFIGURE_DELAY_MS);

    // Act
    amiibo_store_begin(&fixture.amiibo, AMIIBO_V2_SIZE);
    nfc_session_tick(&fixture.session, 5000);

    // Assert
    ASSERT_EQ(nfc_session_event_counter(&fixture.session), 1);
    return true;
}

static bool test_ending_the_scan_cancels_a_pending_event(void) {
    // Arrange
    load_fixture();
    nfc_session_configure(&fixture.session, FIRST_CONFIGURE, sizeof(FIRST_CONFIGURE));

    // Act
    nfc_session_end(&fixture.session);
    nfc_session_tick(&fixture.session, 5000);

    // Assert
    ASSERT_EQ(nfc_session_event_counter(&fixture.session), 0);
    return true;
}

static bool test_an_event_is_raised_only_once_per_command(void) {
    // Arrange
    load_fixture();
    nfc_session_configure(&fixture.session, REPEAT_CONFIGURE, sizeof(REPEAT_CONFIGURE));

    // Act
    nfc_session_tick(&fixture.session, 1000);
    nfc_session_tick(&fixture.session, 1000);

    // Assert
    ASSERT_EQ(nfc_session_event_counter(&fixture.session), 1);
    return true;
}

static bool test_event_counter_wraps_after_seven(void) {
    // Arrange
    load_fixture();

    // Act
    for (int round = 0; round < 8; round++) {
        nfc_session_configure(&fixture.session, REPEAT_CONFIGURE, sizeof(REPEAT_CONFIGURE));
        nfc_session_tick(&fixture.session, 100);
    }

    // Assert
    ASSERT_EQ(nfc_session_event_counter(&fixture.session), 0);
    return true;
}

TEST_MAIN_BEGIN("nfc_session")
    RUN_TEST(test_loading_an_amiibo_while_the_console_waits_raises_an_event);
    RUN_TEST(test_replacing_the_amiibo_while_the_console_waits_raises_another_event);
    RUN_TEST(test_loading_an_amiibo_before_the_console_scans_raises_no_early_event);
    RUN_TEST(test_loading_an_amiibo_after_the_scan_ended_raises_no_event);
    RUN_TEST(test_clearing_the_amiibo_while_the_console_waits_raises_an_event_and_polls_as_no_tag);
    RUN_TEST(test_a_removed_tag_is_reported_lost_once_after_it_was_seen);
    RUN_TEST(test_an_upload_in_progress_raises_no_event);
    RUN_TEST(test_listener_hears_about_each_read_that_starts);
    RUN_TEST(test_listener_is_silent_when_the_read_is_refused);
    RUN_TEST(test_v3_read_header_carries_the_v3_flag_and_a_contiguous_uid);
    RUN_TEST(test_v3_four_range_read_covers_every_requested_page);
    RUN_TEST(test_commit_in_a_fresh_session_serves_the_sram);
    RUN_TEST(test_commit_on_a_v2_dump_is_refused);
    RUN_TEST(test_commit_exposes_the_sram_after_the_header);
    RUN_TEST(test_poll_in_the_sram_and_registry_phases_has_no_uid);
    RUN_TEST(test_registry_read_serves_the_pages_of_the_requested_slot);
    RUN_TEST(test_registry_read_needs_the_sram_phase_first);
    RUN_TEST(test_registry_ranges_beyond_the_dump_are_refused);
    RUN_TEST(test_each_v3_phase_raises_an_event);
    RUN_TEST(test_event_counter_starts_at_zero);
    RUN_TEST(test_first_configure_raises_an_event_after_about_a_second);
    RUN_TEST(test_repeat_configure_raises_an_event_quickly);
    RUN_TEST(test_start_read_raises_an_event_when_the_data_is_ready);
    RUN_TEST(test_no_event_is_raised_without_a_tag);
    RUN_TEST(test_ending_the_scan_cancels_a_pending_event);
    RUN_TEST(test_an_event_is_raised_only_once_per_command);
    RUN_TEST(test_event_counter_wraps_after_seven);
    RUN_TEST(test_poll_without_a_tag_reports_none);
    RUN_TEST(test_poll_with_a_tag_reports_found_and_the_uid);
    RUN_TEST(test_poll_reports_read_ready_after_start_and_found_after_end);
    RUN_TEST(test_start_without_a_tag_is_refused);
    RUN_TEST(test_read_before_start_returns_nothing);
    RUN_TEST(test_buffer_holds_header_block_echo_and_every_requested_page);
    RUN_TEST(test_chunks_are_sixty_nine_bytes_and_the_last_is_flagged);
    RUN_TEST(test_read_past_the_end_returns_nothing);
    RUN_TEST(test_ranges_beyond_the_dump_are_refused);
    RUN_TEST(test_truncated_start_request_is_refused);
TEST_MAIN_END()
