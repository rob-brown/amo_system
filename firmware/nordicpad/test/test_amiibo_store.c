#include "test_framework.h"

#include "nfc/amiibo_store.h"

static void fill_dump(uint8_t *dump, size_t size) {
    for (size_t index = 0; index < size; index++) {
        dump[index] = (uint8_t)(index * 7 + 3);
    }
}

static bool load_in_chunks(amiibo_store_t *store, const uint8_t *dump, size_t size) {
    if (!amiibo_store_begin(store, size)) {
        return false;
    }
    uint8_t index = 0;
    for (size_t offset = 0; offset < size; offset += AMIIBO_CHUNK_SIZE) {
        size_t length = size - offset < AMIIBO_CHUNK_SIZE ? size - offset : AMIIBO_CHUNK_SIZE;
        if (!amiibo_store_add_chunk(store, index++, &dump[offset], length)) {
            return false;
        }
    }
    return amiibo_store_finish(store);
}

static bool test_chunked_v2_dump_is_stored_intact(void) {
    // Arrange
    static amiibo_store_t store;
    uint8_t dump[AMIIBO_V2_SIZE];
    fill_dump(dump, sizeof(dump));
    amiibo_store_init(&store);

    // Act
    bool loaded = load_in_chunks(&store, dump, sizeof(dump));

    // Assert
    ASSERT(loaded);
    ASSERT(amiibo_store_is_loaded(&store));
    ASSERT_EQ(store.size, AMIIBO_V2_SIZE);
    ASSERT_MEM_EQ(store.data, dump, sizeof(dump));
    return true;
}

static bool test_chunked_v3_dump_is_stored_intact(void) {
    // Arrange
    static amiibo_store_t store;
    uint8_t dump[AMIIBO_V3_SIZE];
    fill_dump(dump, sizeof(dump));
    amiibo_store_init(&store);

    // Act
    bool loaded = load_in_chunks(&store, dump, sizeof(dump));

    // Assert
    ASSERT(loaded);
    ASSERT_MEM_EQ(store.data, dump, sizeof(dump));
    return true;
}

static bool test_sizes_other_than_v2_or_v3_are_refused(void) {
    // Arrange
    static amiibo_store_t store;
    amiibo_store_init(&store);

    // Act
    bool small = amiibo_store_begin(&store, 539);
    bool large = amiibo_store_begin(&store, 2049);

    // Assert
    ASSERT(!small);
    ASSERT(!large);
    ASSERT(!amiibo_store_is_loaded(&store));
    return true;
}

static bool test_chunks_must_arrive_in_order(void) {
    // Arrange
    static amiibo_store_t store;
    uint8_t dump[AMIIBO_V2_SIZE];
    fill_dump(dump, sizeof(dump));
    amiibo_store_init(&store);
    amiibo_store_begin(&store, sizeof(dump));

    // Act
    bool skipped = amiibo_store_add_chunk(&store, 1, dump, AMIIBO_CHUNK_SIZE);

    // Assert
    ASSERT(!skipped);
    return true;
}

static bool test_short_chunk_before_the_end_is_refused(void) {
    // Arrange
    static amiibo_store_t store;
    uint8_t dump[AMIIBO_V2_SIZE];
    fill_dump(dump, sizeof(dump));
    amiibo_store_init(&store);
    amiibo_store_begin(&store, sizeof(dump));

    // Act
    bool accepted = amiibo_store_add_chunk(&store, 0, dump, 64);

    // Assert
    ASSERT(!accepted);
    return true;
}

static bool test_data_beyond_the_declared_size_is_refused(void) {
    // Arrange
    static amiibo_store_t store;
    uint8_t dump[AMIIBO_V2_SIZE];
    fill_dump(dump, sizeof(dump));
    amiibo_store_init(&store);
    amiibo_store_begin(&store, sizeof(dump));
    for (uint8_t index = 0; index < 4; index++) {
        amiibo_store_add_chunk(&store, index, dump, AMIIBO_CHUNK_SIZE);
    }

    // Act
    bool last = amiibo_store_add_chunk(&store, 4, dump, AMIIBO_CHUNK_SIZE);

    // Assert
    ASSERT(!last);
    return true;
}

static bool test_finish_requires_every_byte(void) {
    // Arrange
    static amiibo_store_t store;
    uint8_t dump[AMIIBO_V2_SIZE];
    fill_dump(dump, sizeof(dump));
    amiibo_store_init(&store);
    amiibo_store_begin(&store, sizeof(dump));
    amiibo_store_add_chunk(&store, 0, dump, AMIIBO_CHUNK_SIZE);

    // Act
    bool finished = amiibo_store_finish(&store);

    // Assert
    ASSERT(!finished);
    ASSERT(!amiibo_store_is_loaded(&store));
    return true;
}

static bool test_uid_skips_the_check_byte(void) {
    // Arrange
    static amiibo_store_t store;
    uint8_t dump[AMIIBO_V2_SIZE];
    fill_dump(dump, sizeof(dump));
    uint8_t uid[AMIIBO_UID_SIZE];
    amiibo_store_init(&store);
    amiibo_store_load(&store, dump, sizeof(dump));

    // Act
    amiibo_store_uid(&store, uid);

    // Assert
    ASSERT_MEM_EQ(uid, ((const uint8_t[]){dump[0], dump[1], dump[2], dump[4], dump[5], dump[6], dump[7]}), AMIIBO_UID_SIZE);
    return true;
}

static bool test_v3_uid_is_the_first_seven_bytes(void) {
    // Arrange
    static amiibo_store_t store;
    uint8_t dump[AMIIBO_V3_SIZE];
    fill_dump(dump, sizeof(dump));
    uint8_t uid[AMIIBO_UID_SIZE];
    amiibo_store_init(&store);
    amiibo_store_load(&store, dump, sizeof(dump));

    // Act
    amiibo_store_uid(&store, uid);

    // Assert
    ASSERT_MEM_EQ(uid, dump, AMIIBO_UID_SIZE);
    return true;
}

static bool test_clear_forgets_the_dump(void) {
    // Arrange
    static amiibo_store_t store;
    uint8_t dump[AMIIBO_V2_SIZE];
    fill_dump(dump, sizeof(dump));
    uint8_t uid[AMIIBO_UID_SIZE];
    amiibo_store_init(&store);
    amiibo_store_load(&store, dump, sizeof(dump));

    // Act
    amiibo_store_clear(&store);
    amiibo_store_uid(&store, uid);

    // Assert
    ASSERT(!amiibo_store_is_loaded(&store));
    ASSERT_MEM_EQ(uid, ((const uint8_t[]){0, 0, 0, 0, 0, 0, 0}), AMIIBO_UID_SIZE);
    return true;
}

static bool test_starting_a_new_load_discards_the_previous_dump(void) {
    // Arrange
    static amiibo_store_t store;
    uint8_t dump[AMIIBO_V2_SIZE];
    fill_dump(dump, sizeof(dump));
    amiibo_store_init(&store);
    amiibo_store_load(&store, dump, sizeof(dump));

    // Act
    amiibo_store_begin(&store, AMIIBO_V3_SIZE);

    // Assert
    ASSERT(!amiibo_store_is_loaded(&store));
    ASSERT_EQ(store.received, 0);
    return true;
}

TEST_MAIN_BEGIN("amiibo_store")
    RUN_TEST(test_chunked_v2_dump_is_stored_intact);
    RUN_TEST(test_chunked_v3_dump_is_stored_intact);
    RUN_TEST(test_sizes_other_than_v2_or_v3_are_refused);
    RUN_TEST(test_chunks_must_arrive_in_order);
    RUN_TEST(test_short_chunk_before_the_end_is_refused);
    RUN_TEST(test_data_beyond_the_declared_size_is_refused);
    RUN_TEST(test_finish_requires_every_byte);
    RUN_TEST(test_uid_skips_the_check_byte);
    RUN_TEST(test_v3_uid_is_the_first_seven_bytes);
    RUN_TEST(test_clear_forgets_the_dump);
    RUN_TEST(test_starting_a_new_load_discards_the_previous_dump);
TEST_MAIN_END()
