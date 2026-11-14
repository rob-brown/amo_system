#ifndef STORAGE_RAM_PAIRING_STORE_H
#define STORAGE_RAM_PAIRING_STORE_H

#include "storage/pairing_store.h"

typedef struct {
    pairing_record_t record;
    bool occupied;
    pairing_store_t store;
} ram_pairing_store_t;

void ram_pairing_store_init(ram_pairing_store_t *ram_store);

#endif
