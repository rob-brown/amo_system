#include "test_framework.h"

#include <stdio.h>
#include <string.h>

#include "storage/file_pairing_store.h"

#define TEST_PATH "/tmp/nordicpad_test_pairing.bin"

static pairing_record_t sample_record(void) {
    pairing_record_t record;
    for (int index = 0; index < PAIRING_RECORD_KEY_SIZE; index++) {
        record.link_key[index] = (uint8_t)(0x10 + index);
    }
    return record;
}

static bool test_saved_record_loads_from_a_new_store_instance(void) {
    // Arrange
    remove(TEST_PATH);
    file_pairing_store_t writer;
    file_pairing_store_t reader;
    const pairing_record_t original = sample_record();
    pairing_record_t loaded;
    file_pairing_store_init(&writer, TEST_PATH);
    file_pairing_store_init(&reader, TEST_PATH);

    // Act
    bool saved = writer.store.save(writer.store.context, &original);
    bool found = reader.store.load(reader.store.context, &loaded);

    // Assert
    ASSERT(saved);
    ASSERT(found);
    ASSERT_MEM_EQ(loaded.link_key, original.link_key, PAIRING_RECORD_KEY_SIZE);
    remove(TEST_PATH);
    return true;
}

static bool test_missing_file_has_no_record(void) {
    // Arrange
    remove(TEST_PATH);
    file_pairing_store_t file_store;
    pairing_record_t loaded;
    file_pairing_store_init(&file_store, TEST_PATH);

    // Act
    bool found = file_store.store.load(file_store.store.context, &loaded);

    // Assert
    ASSERT(!found);
    return true;
}

static bool test_garbage_file_has_no_record(void) {
    // Arrange
    FILE *file = fopen(TEST_PATH, "wb");
    ASSERT(file != NULL);
    fputs("not a pairing record at all, just text", file);
    fclose(file);
    file_pairing_store_t file_store;
    pairing_record_t loaded;
    file_pairing_store_init(&file_store, TEST_PATH);

    // Act
    bool found = file_store.store.load(file_store.store.context, &loaded);

    // Assert
    ASSERT(!found);
    remove(TEST_PATH);
    return true;
}

TEST_MAIN_BEGIN("file_pairing_store")
    RUN_TEST(test_saved_record_loads_from_a_new_store_instance);
    RUN_TEST(test_missing_file_has_no_record);
    RUN_TEST(test_garbage_file_has_no_record);
TEST_MAIN_END()
