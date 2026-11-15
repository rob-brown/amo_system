#include "nfc/nfc_write.h"

#include <string.h>

#define PIECE_HEADER_SIZE 4
#define UID_OFFSET 2
#define PAGE_SIZE 4
#define SECTOR_SIZE 1024
#define PAGE_BYTE_COUNT 4

typedef struct {
    size_t header_size;
    size_t header_page_offset;
    size_t header_page_destination;
    bool has_sector;
} write_format_t;

static const write_format_t APP_DATA_FORMAT = {
    .header_size = 21,
    .header_page_offset = 17,
    .header_page_destination = 4 * PAGE_SIZE,
    .has_sector = false,
};

static const write_format_t SLOT_FORMAT = {
    .header_size = 22,
    .header_page_offset = 18,
    .header_page_destination = SECTOR_SIZE,
    .has_sector = true,
};

static uint16_t read_u16(const uint8_t *bytes) {
    return (uint16_t)(bytes[0] | (bytes[1] << 8));
}

static bool uid_matches(const nfc_write_buffer_t *buffer, const amiibo_store_t *store) {
    uint8_t uid[AMIIBO_UID_SIZE];

    amiibo_store_uid(store, uid);
    return memcmp(&buffer->data[UID_OFFSET], uid, AMIIBO_UID_SIZE) == 0;
}

static bool walk_chunks(const nfc_write_buffer_t *buffer, amiibo_store_t *store, const write_format_t *format, bool apply) {
    size_t chunk_header_size = format->has_sector ? 3 : 2;
    size_t count_index = format->header_size;
    size_t position = count_index + 1;

    if (buffer->length < position || format->header_page_destination + PAGE_BYTE_COUNT > store->size) {
        return false;
    }
    if (apply) {
        memcpy(&store->data[format->header_page_destination], &buffer->data[format->header_page_offset], PAGE_BYTE_COUNT);
    }

    for (size_t index = 0; index < buffer->data[count_index]; index++) {
        if (position + chunk_header_size > buffer->length) {
            return false;
        }
        const uint8_t *chunk = &buffer->data[position];
        size_t sector = format->has_sector ? chunk[0] : 0;
        size_t page = chunk[format->has_sector ? 1 : 0];
        size_t size = chunk[format->has_sector ? 2 : 1];
        size_t destination = sector * SECTOR_SIZE + page * PAGE_SIZE;
        position += chunk_header_size;

        if (size % PAGE_SIZE != 0 || position + size > buffer->length || destination + size > store->size) {
            return false;
        }
        if (apply) {
            memcpy(&store->data[destination], &buffer->data[position], size);
        }
        position += size;
    }
    return true;
}

static bool apply_format(const nfc_write_buffer_t *buffer, amiibo_store_t *store, const write_format_t *format) {
    if (!amiibo_store_is_loaded(store) || buffer->length <= format->header_size || !uid_matches(buffer, store)) {
        return false;
    }
    if (!walk_chunks(buffer, store, format, false)) {
        return false;
    }
    return walk_chunks(buffer, store, format, true);
}

void nfc_write_buffer_reset(nfc_write_buffer_t *buffer) {
    buffer->length = 0;
}

bool nfc_write_buffer_add_piece(nfc_write_buffer_t *buffer, const uint8_t *payload, size_t length) {
    if (length < PIECE_HEADER_SIZE) {
        return false;
    }

    size_t offset = read_u16(payload);
    size_t size = read_u16(&payload[2]);
    if (length < PIECE_HEADER_SIZE + size || offset + size > NFC_WRITE_CAPACITY) {
        return false;
    }

    if (offset == 0) {
        nfc_write_buffer_reset(buffer);
    }
    memcpy(&buffer->data[offset], &payload[PIECE_HEADER_SIZE], size);
    if (offset + size > buffer->length) {
        buffer->length = offset + size;
    }
    return true;
}

bool nfc_write_apply_slots(const nfc_write_buffer_t *buffer, amiibo_store_t *store) {
    return apply_format(buffer, store, &SLOT_FORMAT);
}

bool nfc_write_apply_app_data(const nfc_write_buffer_t *buffer, amiibo_store_t *store) {
    return apply_format(buffer, store, &APP_DATA_FORMAT);
}
