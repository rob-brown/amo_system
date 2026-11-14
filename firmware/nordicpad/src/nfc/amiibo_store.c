#include "nfc/amiibo_store.h"

#include <string.h>

static const size_t V2_UID_OFFSETS[AMIIBO_UID_SIZE] = {0, 1, 2, 4, 5, 6, 7};
static const size_t V3_UID_OFFSETS[AMIIBO_UID_SIZE] = {0, 1, 2, 3, 4, 5, 6};

static bool valid_size(size_t size) {
    return size == AMIIBO_V2_SIZE || size == AMIIBO_V3_SIZE;
}

void amiibo_store_init(amiibo_store_t *store) {
    memset(store, 0, sizeof(*store));
    store->state = AMIIBO_STORE_EMPTY;
}

bool amiibo_store_begin(amiibo_store_t *store, size_t size) {
    if (!valid_size(size)) {
        return false;
    }
    amiibo_store_clear(store);
    store->size = size;
    store->state = AMIIBO_STORE_LOADING;
    return true;
}

bool amiibo_store_add_chunk(amiibo_store_t *store, uint8_t index, const uint8_t *data, size_t length) {
    if (store->state != AMIIBO_STORE_LOADING || index != store->next_chunk || length == 0 || length > AMIIBO_CHUNK_SIZE) {
        return false;
    }
    if (store->received + length > store->size) {
        return false;
    }
    bool final_chunk = store->received + length == store->size;
    if (length != AMIIBO_CHUNK_SIZE && !final_chunk) {
        return false;
    }

    memcpy(&store->data[store->received], data, length);
    store->received += length;
    store->next_chunk++;
    return true;
}

bool amiibo_store_finish(amiibo_store_t *store) {
    if (store->state != AMIIBO_STORE_LOADING || store->received != store->size) {
        return false;
    }
    store->state = AMIIBO_STORE_LOADED;
    return true;
}

bool amiibo_store_load(amiibo_store_t *store, const uint8_t *data, size_t length) {
    if (!amiibo_store_begin(store, length)) {
        return false;
    }
    memcpy(store->data, data, length);
    store->received = length;
    return amiibo_store_finish(store);
}

void amiibo_store_clear(amiibo_store_t *store) {
    memset(store, 0, sizeof(*store));
    store->state = AMIIBO_STORE_EMPTY;
}

bool amiibo_store_is_loaded(const amiibo_store_t *store) {
    return store->state == AMIIBO_STORE_LOADED;
}

void amiibo_store_uid(const amiibo_store_t *store, uint8_t uid[AMIIBO_UID_SIZE]) {
    if (!amiibo_store_is_loaded(store)) {
        memset(uid, 0, AMIIBO_UID_SIZE);
        return;
    }
    const size_t *offsets = store->size == AMIIBO_V3_SIZE ? V3_UID_OFFSETS : V2_UID_OFFSETS;
    for (size_t index = 0; index < AMIIBO_UID_SIZE; index++) {
        uid[index] = store->data[offsets[index]];
    }
}
