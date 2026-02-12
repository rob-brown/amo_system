#include "bonding_storage.h"
#include "logging.h"
#include "pico/stdlib.h"
#include "hardware/flash.h"
#include "hardware/sync.h"
#include "btstack.h"
#include "classic/btstack_link_key_db_memory.h"
#include <string.h>
#include <stdio.h>

#define FLASH_TARGET_OFFSET (PICO_FLASH_SIZE_BYTES - FLASH_SECTOR_SIZE)
#define BONDING_MAGIC 0x424F4E44

typedef struct {
    uint32_t magic;
    bd_addr_t addr;
    uint32_t timestamp;
    uint16_t connection_count;
} __attribute__((packed)) bonding_flash_data_t;

static bool initialized = false;
static bonding_stats_t current_stats;

static void load_from_flash(void) {
    const bonding_flash_data_t *flash_data = (const bonding_flash_data_t *)(XIP_BASE + FLASH_TARGET_OFFSET);

    if (flash_data->magic == BONDING_MAGIC) {
        memcpy(current_stats.addr, flash_data->addr, 6);
        current_stats.timestamp = flash_data->timestamp;
        current_stats.connection_count = flash_data->connection_count;
        pico_log_noticef("Loaded bonding from flash: %s (count=%d)",
                  bd_addr_to_str(current_stats.addr), current_stats.connection_count);
    } else {
        pico_log_notice("No valid bonding data in flash");
        memset(&current_stats, 0, sizeof(current_stats));
    }
}

static void save_to_flash(void) {
    bonding_flash_data_t data;
    data.magic = BONDING_MAGIC;
    memcpy(data.addr, current_stats.addr, 6);
    data.timestamp = current_stats.timestamp;
    data.connection_count = current_stats.connection_count;

    uint32_t ints = save_and_disable_interrupts();
    flash_range_erase(FLASH_TARGET_OFFSET, FLASH_SECTOR_SIZE);
    flash_range_program(FLASH_TARGET_OFFSET, (const uint8_t *)&data, sizeof(data));
    restore_interrupts(ints);
}

void bonding_storage_init(void) {
    if (initialized) {
        return;
    }

    pico_log_debug("Initializing bonding storage");

    memset(&current_stats, 0, sizeof(current_stats));
    load_from_flash();

    initialized = true;
}

bool bonding_storage_save_last_connected(bd_addr_t addr) {
    if (!initialized) {
        return false;
    }

    memcpy(current_stats.addr, addr, 6);
    current_stats.timestamp = to_ms_since_boot(get_absolute_time());
    current_stats.connection_count++;

    save_to_flash();

    pico_log_noticef("Saved last connected: %s (count=%d)",
              bd_addr_to_str(addr), current_stats.connection_count);

    return true;
}

bool bonding_storage_load_last_connected(bd_addr_t addr) {
    if (!initialized) {
        return false;
    }

    bd_addr_t zero_addr = {0, 0, 0, 0, 0, 0};
    if (memcmp(current_stats.addr, zero_addr, 6) == 0) {
        return false;
    }

    memcpy(addr, current_stats.addr, 6);
    pico_log_noticef("Loaded last connected: %s", bd_addr_to_str(addr));

    return true;
}

void bonding_storage_clear(void) {
    if (!initialized) {
        return;
    }

    pico_log_notice("Clearing bonding storage");

    memset(&current_stats, 0, sizeof(current_stats));

    const btstack_link_key_db_t *db = bonding_storage_get_link_key_db();
    if (db && db->delete_link_key) {
        bd_addr_t zero_addr = {0, 0, 0, 0, 0, 0};
        if (memcmp(current_stats.addr, zero_addr, 6) != 0) {
            db->delete_link_key(current_stats.addr);
        }
    }

    uint32_t ints = save_and_disable_interrupts();
    flash_range_erase(FLASH_TARGET_OFFSET, FLASH_SECTOR_SIZE);
    restore_interrupts(ints);
}

bool bonding_storage_is_bonded(void) {
    if (!initialized) {
        return false;
    }

    bd_addr_t zero_addr = {0, 0, 0, 0, 0, 0};
    return memcmp(current_stats.addr, zero_addr, 6) != 0;
}

void bonding_storage_get_stats(uint32_t *timestamp, uint16_t *count) {
    if (timestamp) {
        *timestamp = current_stats.timestamp;
    }
    if (count) {
        *count = current_stats.connection_count;
    }
}

const btstack_link_key_db_t *bonding_storage_get_link_key_db(void) {
    static const btstack_link_key_db_t *db = NULL;
    if (!db) {
        db = btstack_link_key_db_memory_instance();
    }
    return db;
}
