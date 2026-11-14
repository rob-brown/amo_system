#include "storage/zephyr_flash_pairing_store.h"

#include <string.h>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/flash.h>

#include "platform/log.h"
#include "storage/pairing_record_codec.h"

#define STORAGE_OFFSET DT_REG_ADDR(DT_NODELABEL(storage_partition))
#define ERASE_SIZE 4096

static const struct device *flash_device(void) {
    return DEVICE_DT_GET(DT_CHOSEN(zephyr_flash_controller));
}

static bool flash_load(void *context, pairing_record_t *record) {
    (void)context;
    uint8_t image[PAIRING_IMAGE_SIZE];

    return flash_read(flash_device(), STORAGE_OFFSET, image, sizeof(image)) == 0 && pairing_record_decode(image, record);
}

static bool flash_save(void *context, const pairing_record_t *record) {
    (void)context;
    uint8_t image[PAIRING_IMAGE_SIZE];

    memset(image, 0xFF, sizeof(image));
    pairing_record_encode(record, image);
    bool saved = flash_erase(flash_device(), STORAGE_OFFSET, ERASE_SIZE) == 0 &&
                 flash_write(flash_device(), STORAGE_OFFSET, image, sizeof(image)) == 0;
    LOG("pairing record %s", saved ? "saved to flash" : "could not be saved");
    return saved;
}

static bool flash_clear(void *context) {
    (void)context;

    bool cleared = flash_erase(flash_device(), STORAGE_OFFSET, ERASE_SIZE) == 0;
    LOG("pairing record %s", cleared ? "erased from flash" : "could not be erased");
    return cleared;
}

const pairing_store_t *zephyr_flash_pairing_store(void) {
    static const pairing_store_t store = {.load = flash_load, .save = flash_save, .clear = flash_clear, .context = NULL};

    return &store;
}
