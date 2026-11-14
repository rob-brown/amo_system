#ifndef NFC_AMIIBO_STORE_H
#define NFC_AMIIBO_STORE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define AMIIBO_V2_SIZE 540
#define AMIIBO_V3_SIZE 2048
#define AMIIBO_CHUNK_SIZE 128
#define AMIIBO_UID_SIZE 7

typedef enum {
    AMIIBO_STORE_EMPTY,
    AMIIBO_STORE_LOADING,
    AMIIBO_STORE_LOADED
} amiibo_store_state_t;

typedef struct {
    uint8_t data[AMIIBO_V3_SIZE];
    size_t size;
    size_t received;
    uint8_t next_chunk;
    amiibo_store_state_t state;
    uint32_t generation;
} amiibo_store_t;

void amiibo_store_init(amiibo_store_t *store);

bool amiibo_store_begin(amiibo_store_t *store, size_t size);

bool amiibo_store_add_chunk(amiibo_store_t *store, uint8_t index, const uint8_t *data, size_t length);

bool amiibo_store_finish(amiibo_store_t *store);

bool amiibo_store_load(amiibo_store_t *store, const uint8_t *data, size_t length);

void amiibo_store_clear(amiibo_store_t *store);

bool amiibo_store_is_loaded(const amiibo_store_t *store);

void amiibo_store_uid(const amiibo_store_t *store, uint8_t uid[AMIIBO_UID_SIZE]);

#endif
