#include "test_framework.h"
#include "test_write_support.h"

#include "nfc/nfc_write.h"

static amiibo_store_t store;
static nfc_write_buffer_t buffer;
static uint8_t original[AMIIBO_V3_SIZE];

static void load_v3_store(void) {
    for (size_t index = 0; index < sizeof(original); index++) {
        original[index] = (uint8_t)(index * 7 + 3);
    }
    amiibo_store_init(&store);
    amiibo_store_load(&store, original, sizeof(original));
    nfc_write_buffer_reset(&buffer);
}

static void add_pieces(const uint8_t *data, size_t length) {
    for (size_t index = 0; index < write_piece_count(length); index++) {
        uint8_t piece[WRITE_PIECE_SIZE];

        write_piece_at(data, length, index, piece);
        nfc_write_buffer_add_piece(&buffer, piece, sizeof(piece));
    }
}

static bool test_pieces_are_assembled_by_offset(void) {
    // Arrange
    load_v3_store();
    uint8_t data[200];
    for (size_t index = 0; index < sizeof(data); index++) {
        data[index] = (uint8_t)index;
    }

    // Act
    add_pieces(data, sizeof(data));

    // Assert
    ASSERT_EQ(buffer.length, sizeof(data));
    ASSERT_MEM_EQ(buffer.data, data, sizeof(data));
    return true;
}

static bool test_a_piece_at_offset_zero_starts_a_new_buffer(void) {
    // Arrange
    load_v3_store();
    uint8_t first[150] = {0};
    uint8_t second[10] = {0};
    add_pieces(first, sizeof(first));

    // Act
    add_pieces(second, sizeof(second));

    // Assert
    ASSERT_EQ(buffer.length, sizeof(second));
    return true;
}

static bool test_malformed_pieces_are_refused(void) {
    // Arrange
    load_v3_store();
    uint8_t truncated[6] = {0, 0, 10, 0, 1, 2};
    uint8_t oversized[WRITE_PIECE_SIZE] = {0xF0, 0x01, 0x4C, 0x00};

    // Act
    bool short_accepted = nfc_write_buffer_add_piece(&buffer, truncated, sizeof(truncated));
    bool big_accepted = nfc_write_buffer_add_piece(&buffer, oversized, sizeof(oversized));
    bool tiny_accepted = nfc_write_buffer_add_piece(&buffer, truncated, 3);

    // Assert
    ASSERT(!short_accepted);
    ASSERT(!big_accepted);
    ASSERT(!tiny_accepted);
    return true;
}

static bool test_app_data_write_replaces_page_four_and_every_chunk(void) {
    // Arrange
    load_v3_store();
    uint8_t data[64];
    add_pieces(data, build_app_data_write(data, original));

    // Act
    bool applied = nfc_write_apply_app_data(&buffer, &store);

    // Assert
    ASSERT(applied);
    ASSERT_MEM_EQ(&store.data[0x10], ((const uint8_t[]){0xA5, 0x83, 0xF6, 0x00}), 4);
    ASSERT_EQ(store.data[0x14], 0x11);
    ASSERT_EQ(store.data[0x1B], 0x11);
    ASSERT_EQ(store.data[0x1C], original[0x1C]);
    ASSERT_EQ(store.data[0xC0], 0x22);
    ASSERT_EQ(store.data[0xCB], 0x22);
    ASSERT_EQ(store.data[0xCC], original[0xCC]);
    return true;
}

static bool test_slot_write_replaces_both_sectors(void) {
    // Arrange
    load_v3_store();
    uint8_t data[64];
    add_pieces(data, build_slot_write(data, original));

    // Act
    bool applied = nfc_write_apply_slots(&buffer, &store);

    // Assert
    ASSERT(applied);
    ASSERT_MEM_EQ(&store.data[0x400], ((const uint8_t[]){0xA5, 0x00, 0x04, 0x00}), 4);
    ASSERT_EQ(store.data[0x248], 0x33);
    ASSERT_EQ(store.data[0x24F], 0x33);
    ASSERT_EQ(store.data[0x250], original[0x250]);
    ASSERT_EQ(store.data[0x404], 0x44);
    ASSERT_EQ(store.data[0x40F], 0x44);
    ASSERT_EQ(store.data[0x410], original[0x410]);
    return true;
}

static bool test_slot_header_goes_to_the_start_of_the_written_slot(void) {
    // Arrange
    load_v3_store();
    uint8_t data[64];
    add_pieces(data, build_slot_write_for(data, original, 3));

    // Act
    bool applied = nfc_write_apply_slots(&buffer, &store);

    // Assert
    ASSERT(applied);
    ASSERT_MEM_EQ(&store.data[0x52C], ((const uint8_t[]){0xA5, 0x00, 0x04, 0x00}), 4);
    ASSERT_EQ(store.data[0x530], 0x44);
    ASSERT_MEM_EQ(&store.data[0x400], &original[0x400], 4);
    ASSERT_EQ(store.data[0x248 + 32 * 3], 0x33);
    return true;
}

static bool test_a_write_for_another_uid_changes_nothing(void) {
    // Arrange
    load_v3_store();
    uint8_t other_uid[AMIIBO_UID_SIZE] = {1, 2, 3, 4, 5, 6, 7};
    uint8_t data[64];
    add_pieces(data, build_app_data_write(data, other_uid));

    // Act
    bool applied = nfc_write_apply_app_data(&buffer, &store);

    // Assert
    ASSERT(!applied);
    ASSERT_MEM_EQ(store.data, original, sizeof(original));
    return true;
}

static bool test_a_misaligned_chunk_leaves_the_dump_untouched(void) {
    // Arrange
    load_v3_store();
    uint8_t data[64];
    size_t length = build_app_data_write(data, original);
    data[length - 13] = 0x0B;
    add_pieces(data, length);

    // Act
    bool applied = nfc_write_apply_app_data(&buffer, &store);

    // Assert
    ASSERT(!applied);
    ASSERT_MEM_EQ(store.data, original, sizeof(original));
    return true;
}

static bool test_a_chunk_beyond_a_v2_dump_leaves_the_dump_untouched(void) {
    // Arrange
    load_v3_store();
    amiibo_store_load(&store, original, AMIIBO_V2_SIZE);
    uint8_t data[64];
    size_t length = build_app_data_write(data, original);
    data[length - 14] = 0xFF;
    add_pieces(data, length);

    // Act
    bool applied = nfc_write_apply_app_data(&buffer, &store);

    // Assert
    ASSERT(!applied);
    ASSERT_MEM_EQ(store.data, original, AMIIBO_V2_SIZE);
    return true;
}

static bool test_slot_write_is_refused_on_a_v2_dump(void) {
    // Arrange
    load_v3_store();
    amiibo_store_load(&store, original, AMIIBO_V2_SIZE);
    uint8_t data[64];
    add_pieces(data, build_slot_write(data, original));

    // Act
    bool applied = nfc_write_apply_slots(&buffer, &store);

    // Assert
    ASSERT(!applied);
    ASSERT_MEM_EQ(store.data, original, AMIIBO_V2_SIZE);
    return true;
}

static bool test_a_write_without_a_loaded_amiibo_is_refused(void) {
    // Arrange
    load_v3_store();
    uint8_t data[64];
    add_pieces(data, build_app_data_write(data, original));
    amiibo_store_clear(&store);

    // Act
    bool applied = nfc_write_apply_app_data(&buffer, &store);

    // Assert
    ASSERT(!applied);
    return true;
}

TEST_MAIN_BEGIN("nfc_write")
    RUN_TEST(test_pieces_are_assembled_by_offset);
    RUN_TEST(test_a_piece_at_offset_zero_starts_a_new_buffer);
    RUN_TEST(test_malformed_pieces_are_refused);
    RUN_TEST(test_app_data_write_replaces_page_four_and_every_chunk);
    RUN_TEST(test_slot_write_replaces_both_sectors);
    RUN_TEST(test_slot_header_goes_to_the_start_of_the_written_slot);
    RUN_TEST(test_a_write_for_another_uid_changes_nothing);
    RUN_TEST(test_a_misaligned_chunk_leaves_the_dump_untouched);
    RUN_TEST(test_a_chunk_beyond_a_v2_dump_leaves_the_dump_untouched);
    RUN_TEST(test_slot_write_is_refused_on_a_v2_dump);
    RUN_TEST(test_a_write_without_a_loaded_amiibo_is_refused);
TEST_MAIN_END()
