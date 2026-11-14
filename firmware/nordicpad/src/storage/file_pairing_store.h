#ifndef STORAGE_FILE_PAIRING_STORE_H
#define STORAGE_FILE_PAIRING_STORE_H

#include "storage/pairing_store.h"

#define FILE_PAIRING_STORE_PATH_MAX 256

typedef struct {
    char path[FILE_PAIRING_STORE_PATH_MAX];
    pairing_store_t store;
} file_pairing_store_t;

void file_pairing_store_init(file_pairing_store_t *file_store, const char *path);

#endif
