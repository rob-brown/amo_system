#include "storage/ram_pairing_store.h"

static bool ram_load(void *context, pairing_record_t *record) {
    const ram_pairing_store_t *ram_store = context;

    if (!ram_store->occupied) {
        return false;
    }

    *record = ram_store->record;
    return true;
}

static bool ram_save(void *context, const pairing_record_t *record) {
    ram_pairing_store_t *ram_store = context;

    ram_store->record = *record;
    ram_store->occupied = true;
    return true;
}

void ram_pairing_store_init(ram_pairing_store_t *ram_store) {
    ram_store->occupied = false;
    ram_store->store.load = ram_load;
    ram_store->store.save = ram_save;
    ram_store->store.context = ram_store;
}
