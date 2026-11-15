#include "nfc/nfc_buffer.h"

#include <string.h>

#define TAG_INFO_OFFSET 4
#define V3_HEADER_FLAG_OFFSET 18
#define V3_HEADER_FLAG 0x06
#define PAGE_SIZE 4
#define MIN_RANGE_ECHO_SIZE 3
#define REGISTRY_ENTRY_SIZE 3

static const uint8_t TAG_INFO[4] = {0x01, 0x02, 0x00, 0x07};

static const uint8_t V2_BLOCK[NFC_BLOCK_SIZE] = {
    0x13, 0x4F, 0x69, 0x39, 0xB9, 0xBC, 0x95, 0x16, 0xD2, 0x5A, 0x11, 0x68, 0x23, 0xF1, 0xC0, 0x0B,
    0xA4, 0xB5, 0x6E, 0xEA, 0xBE, 0xE9, 0xA9, 0x59, 0x3C, 0x8D, 0x36, 0xAE, 0x7A, 0xD1, 0x9A, 0x65,
};

static const uint8_t V3_BLOCK[NFC_BLOCK_SIZE] = {
    0xA9, 0x78, 0xFF, 0x79, 0xCA, 0x96, 0x1C, 0x06, 0x30, 0xBB, 0xCD, 0x5F, 0xF9, 0xC3, 0xF1, 0xB2,
    0xA6, 0x1F, 0xF6, 0x44, 0x71, 0xC7, 0x4F, 0xAD, 0x43, 0xAA, 0xD7, 0x42, 0x16, 0x43, 0xCB, 0xD9,
};

static bool is_v3(const amiibo_store_t *amiibo) {
    return amiibo->size == AMIIBO_V3_SIZE;
}

static void write_read_header(const amiibo_store_t *amiibo, uint8_t status, uint8_t out[NFC_READ_HEADER_SIZE]) {
    memset(out, 0, NFC_READ_HEADER_SIZE);
    out[0] = status;
    nfc_write_tag_info(&out[TAG_INFO_OFFSET], amiibo);
    if (is_v3(amiibo)) {
        out[V3_HEADER_FLAG_OFFSET] = V3_HEADER_FLAG;
    }
}

static size_t append_sector0_range(const amiibo_store_t *amiibo, uint8_t first, uint8_t last, uint8_t *out, size_t used, size_t capacity) {
    size_t length = ((size_t)last - first + 1) * PAGE_SIZE;
    size_t offset = (size_t)first * PAGE_SIZE;
    if (last < first || offset + length > amiibo->size || used + length > capacity) {
        return 0;
    }
    memcpy(&out[used], &amiibo->data[offset], length);
    return length;
}

void nfc_write_tag_info(uint8_t out[NFC_TAG_INFO_SIZE], const amiibo_store_t *amiibo) {
    memcpy(out, TAG_INFO, sizeof(TAG_INFO));
    amiibo_store_uid(amiibo, &out[sizeof(TAG_INFO)]);
}

size_t nfc_build_range_buffer(const amiibo_store_t *amiibo, const uint8_t *echo, size_t echo_length, uint8_t *out, size_t capacity) {
    size_t used = NFC_READ_HEADER_SIZE + NFC_BLOCK_SIZE + echo_length;
    size_t count = echo_length > 0 ? echo[0] : 0;
    if (count == 0 || echo_length < MIN_RANGE_ECHO_SIZE + 2 * (count - 1) || used > capacity) {
        return 0;
    }

    write_read_header(amiibo, NFC_STATUS_READ_READY, out);
    memcpy(&out[NFC_READ_HEADER_SIZE], is_v3(amiibo) ? V3_BLOCK : V2_BLOCK, NFC_BLOCK_SIZE);
    memcpy(&out[NFC_READ_HEADER_SIZE + NFC_BLOCK_SIZE], echo, echo_length);

    for (size_t index = 0; index < count; index++) {
        uint8_t first = echo[1 + 2 * index];
        uint8_t last = echo[2 + 2 * index];
        size_t added = append_sector0_range(amiibo, first, last, out, used, capacity);
        if (added == 0) {
            return 0;
        }
        used += added;
    }
    return used;
}

size_t nfc_build_sram_buffer(const amiibo_store_t *amiibo, uint8_t *out, size_t capacity) {
    size_t total = NFC_READ_HEADER_SIZE + NFC_SRAM_SIZE;
    if (!is_v3(amiibo) || capacity < total) {
        return 0;
    }

    write_read_header(amiibo, NFC_STATUS_SRAM_READY, out);
    memcpy(&out[NFC_READ_HEADER_SIZE], &amiibo->data[NFC_SRAM_OFFSET], NFC_SRAM_SIZE);
    return total;
}

size_t nfc_build_registry_buffer(const amiibo_store_t *amiibo, const uint8_t *echo, size_t echo_length, uint8_t *out, size_t capacity) {
    size_t used = NFC_READ_HEADER_SIZE + NFC_BLOCK_SIZE + echo_length;
    size_t count = echo_length > 0 ? echo[0] : 0;
    if (!is_v3(amiibo) || count == 0 || echo_length < 1 + REGISTRY_ENTRY_SIZE * count || used > capacity) {
        return 0;
    }

    write_read_header(amiibo, NFC_STATUS_REGISTRY_READY, out);
    memcpy(&out[NFC_READ_HEADER_SIZE], V3_BLOCK, NFC_BLOCK_SIZE);
    memcpy(&out[NFC_READ_HEADER_SIZE + NFC_BLOCK_SIZE], echo, echo_length);

    for (size_t index = 0; index < count; index++) {
        const uint8_t *entry = &echo[1 + REGISTRY_ENTRY_SIZE * index];
        size_t offset = (size_t)entry[0] * NFC_SECTOR_SIZE + (size_t)entry[1] * PAGE_SIZE;
        size_t length = ((size_t)entry[2] - entry[1] + 1) * PAGE_SIZE;
        if (entry[2] < entry[1] || offset + length > amiibo->size || used + length > capacity) {
            return 0;
        }
        memcpy(&out[used], &amiibo->data[offset], length);
        used += length;
    }
    return used;
}
