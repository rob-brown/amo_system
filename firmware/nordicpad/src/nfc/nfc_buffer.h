#ifndef NFC_NFC_BUFFER_H
#define NFC_NFC_BUFFER_H

#include <stddef.h>
#include <stdint.h>

#include "nfc/amiibo_store.h"

#define NFC_STATUS_NO_TAG 0x00
#define NFC_STATUS_TAG_FOUND 0x09
#define NFC_STATUS_READ_READY 0x04
#define NFC_STATUS_SRAM_READY 0x18
#define NFC_STATUS_REGISTRY_READY 0x15

#define NFC_READ_HEADER_SIZE 19
#define NFC_BLOCK_SIZE 32
#define NFC_TAG_INFO_SIZE (4 + AMIIBO_UID_SIZE)
#define NFC_SRAM_OFFSET 960
#define NFC_SRAM_SIZE 64
#define NFC_SECTOR_SIZE 1024

void nfc_write_tag_info(uint8_t out[NFC_TAG_INFO_SIZE], const amiibo_store_t *amiibo);

size_t nfc_build_range_buffer(const amiibo_store_t *amiibo, const uint8_t *echo, size_t echo_length, uint8_t *out, size_t capacity);

size_t nfc_build_sram_buffer(const amiibo_store_t *amiibo, uint8_t *out, size_t capacity);

size_t nfc_build_registry_buffer(const amiibo_store_t *amiibo, const uint8_t *echo, size_t echo_length, uint8_t *out, size_t capacity);

#endif
