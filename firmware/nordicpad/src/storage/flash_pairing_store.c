#include "storage/flash_pairing_store.h"

#include "hardware/flash.h"
#include "hardware/sync.h"
#include "platform/log.h"
#include "storage/pairing_record_codec.h"

#define PAIRING_FLASH_OFFSET (PICO_FLASH_SIZE_BYTES - FLASH_SECTOR_SIZE)

static bool flash_load(void *context, pairing_record_t *record) {
    (void)context;
    const uint8_t *image = (const uint8_t *)(XIP_BASE + PAIRING_FLASH_OFFSET);

    return pairing_record_decode(image, record);
}

static bool flash_save(void *context, const pairing_record_t *record) {
    (void)context;
    uint8_t page[FLASH_PAGE_SIZE];

    for (size_t index = 0; index < sizeof(page); index++) {
        page[index] = 0xFF;
    }
    pairing_record_encode(record, page);

    uint32_t interrupts = save_and_disable_interrupts();
    flash_range_erase(PAIRING_FLASH_OFFSET, FLASH_SECTOR_SIZE);
    flash_range_program(PAIRING_FLASH_OFFSET, page, sizeof(page));
    restore_interrupts(interrupts);

    LOG("pairing record saved to flash");
    return true;
}

static bool flash_clear(void *context) {
    (void)context;

    uint32_t interrupts = save_and_disable_interrupts();
    flash_range_erase(PAIRING_FLASH_OFFSET, FLASH_SECTOR_SIZE);
    restore_interrupts(interrupts);

    LOG("pairing record erased from flash");
    return true;
}

const pairing_store_t *flash_pairing_store(void) {
    static const pairing_store_t store = {.load = flash_load, .save = flash_save, .clear = flash_clear, .context = NULL};

    return &store;
}
