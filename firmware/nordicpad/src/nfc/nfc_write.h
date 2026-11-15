#ifndef NFC_NFC_WRITE_H
#define NFC_NFC_WRITE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nfc/amiibo_store.h"

#define NFC_WRITE_CAPACITY 512

typedef struct {
    uint8_t data[NFC_WRITE_CAPACITY];
    size_t length;
} nfc_write_buffer_t;

void nfc_write_buffer_reset(nfc_write_buffer_t *buffer);

bool nfc_write_buffer_add_piece(nfc_write_buffer_t *buffer, const uint8_t *payload, size_t length);

bool nfc_write_apply_slots(const nfc_write_buffer_t *buffer, amiibo_store_t *store);

bool nfc_write_apply_app_data(const nfc_write_buffer_t *buffer, amiibo_store_t *store);

#endif
