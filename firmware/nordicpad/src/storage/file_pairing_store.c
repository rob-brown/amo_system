#include "storage/file_pairing_store.h"

#include <stdio.h>
#include <string.h>

#include "storage/pairing_record_codec.h"

static bool file_load(void *context, pairing_record_t *record) {
    const file_pairing_store_t *file_store = context;
    uint8_t image[PAIRING_IMAGE_SIZE];

    FILE *file = fopen(file_store->path, "rb");
    if (file == NULL) {
        return false;
    }

    size_t read = fread(image, 1, sizeof(image), file);
    fclose(file);
    return read == sizeof(image) && pairing_record_decode(image, record);
}

static bool file_save(void *context, const pairing_record_t *record) {
    const file_pairing_store_t *file_store = context;
    uint8_t image[PAIRING_IMAGE_SIZE];

    pairing_record_encode(record, image);
    FILE *file = fopen(file_store->path, "wb");
    if (file == NULL) {
        return false;
    }

    size_t written = fwrite(image, 1, sizeof(image), file);
    fclose(file);
    return written == sizeof(image);
}

void file_pairing_store_init(file_pairing_store_t *file_store, const char *path) {
    strncpy(file_store->path, path, sizeof(file_store->path) - 1);
    file_store->path[sizeof(file_store->path) - 1] = '\0';
    file_store->store.load = file_load;
    file_store->store.save = file_save;
    file_store->store.context = file_store;
}
