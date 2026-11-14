#ifndef STORAGE_PAIRING_STORE_H
#define STORAGE_PAIRING_STORE_H

#include <stdbool.h>
#include <stdint.h>

#define PAIRING_RECORD_KEY_SIZE 16
#define PAIRING_RECORD_ADDRESS_SIZE 6

typedef struct {
    uint8_t link_key[PAIRING_RECORD_KEY_SIZE];
    uint8_t host_address[PAIRING_RECORD_ADDRESS_SIZE];
} pairing_record_t;

typedef struct {
    bool (*load)(void *context, pairing_record_t *record);
    bool (*save)(void *context, const pairing_record_t *record);
    void *context;
} pairing_store_t;

#endif
