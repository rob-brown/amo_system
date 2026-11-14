#include "storage/pairing_record_codec.h"

#include <string.h>

#include "host/crc8.h"

#define MAGIC_SIZE 4
#define KEY_OFFSET MAGIC_SIZE
#define ADDRESS_OFFSET (KEY_OFFSET + PAIRING_RECORD_KEY_SIZE)
#define CHECKSUM_OFFSET (ADDRESS_OFFSET + PAIRING_RECORD_ADDRESS_SIZE)

static const uint8_t MAGIC[MAGIC_SIZE] = {'P', 'P', 'D', '3'};

void pairing_record_encode(const pairing_record_t *record, uint8_t image[PAIRING_IMAGE_SIZE]) {
    memset(image, 0xFF, PAIRING_IMAGE_SIZE);
    memcpy(image, MAGIC, MAGIC_SIZE);
    memcpy(&image[KEY_OFFSET], record->link_key, PAIRING_RECORD_KEY_SIZE);
    memcpy(&image[ADDRESS_OFFSET], record->host_address, PAIRING_RECORD_ADDRESS_SIZE);
    image[CHECKSUM_OFFSET] = crc8(image, CHECKSUM_OFFSET);
}

bool pairing_record_decode(const uint8_t image[PAIRING_IMAGE_SIZE], pairing_record_t *record) {
    if (memcmp(image, MAGIC, MAGIC_SIZE) != 0) {
        return false;
    }
    if (image[CHECKSUM_OFFSET] != crc8(image, CHECKSUM_OFFSET)) {
        return false;
    }

    memcpy(record->link_key, &image[KEY_OFFSET], PAIRING_RECORD_KEY_SIZE);
    memcpy(record->host_address, &image[ADDRESS_OFFSET], PAIRING_RECORD_ADDRESS_SIZE);
    return true;
}
