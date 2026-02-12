#ifndef BONDING_STORAGE_H
#define BONDING_STORAGE_H

#include <stdbool.h>
#include <stdint.h>
#include "btstack.h"

#define BONDING_TAG_LAST_CONNECTED 0x504C4243
#define BONDING_TAG_STATS 0x50425354

typedef struct {
    bd_addr_t addr;
    uint32_t timestamp;
    uint16_t connection_count;
} bonding_stats_t;

void bonding_storage_init(void);

bool bonding_storage_save_last_connected(bd_addr_t addr);

bool bonding_storage_load_last_connected(bd_addr_t addr);

void bonding_storage_clear(void);

bool bonding_storage_is_bonded(void);

void bonding_storage_get_stats(uint32_t *timestamp, uint16_t *count);

const btstack_link_key_db_t *bonding_storage_get_link_key_db(void);

#endif
