#ifndef STORAGE_PAIRING_RECORD_CODEC_H
#define STORAGE_PAIRING_RECORD_CODEC_H

#include <stdbool.h>
#include <stdint.h>

#include "storage/pairing_store.h"

#define PAIRING_IMAGE_SIZE 32

void pairing_record_encode(const pairing_record_t *record, uint8_t image[PAIRING_IMAGE_SIZE]);

bool pairing_record_decode(const uint8_t image[PAIRING_IMAGE_SIZE], pairing_record_t *record);

#endif
