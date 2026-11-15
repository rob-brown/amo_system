#ifndef TEST_WRITE_SUPPORT_H
#define TEST_WRITE_SUPPORT_H

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define WRITE_PIECE_DATA_SIZE 76
#define WRITE_PIECE_SIZE 80

static inline size_t write_piece_count(size_t length) {
    return (length + WRITE_PIECE_DATA_SIZE - 1) / WRITE_PIECE_DATA_SIZE;
}

static inline void write_piece_at(const uint8_t *data, size_t length, size_t index, uint8_t piece[WRITE_PIECE_SIZE]) {
    size_t offset = index * WRITE_PIECE_DATA_SIZE;
    size_t size = length - offset < WRITE_PIECE_DATA_SIZE ? length - offset : WRITE_PIECE_DATA_SIZE;

    memset(piece, 0, WRITE_PIECE_SIZE);
    piece[0] = (uint8_t)(offset & 0xFF);
    piece[1] = (uint8_t)(offset >> 8);
    piece[2] = (uint8_t)(size & 0xFF);
    piece[3] = (uint8_t)(size >> 8);
    memcpy(&piece[4], &data[offset], size);
}

static inline size_t write_header(uint8_t *out, size_t header_size, const uint8_t uid[7], const uint8_t page[4], size_t page_offset) {
    memset(out, 0xEE, header_size);
    memcpy(&out[2], uid, 7);
    memcpy(&out[page_offset], page, 4);
    return header_size;
}

static inline size_t build_app_data_write(uint8_t *out, const uint8_t uid[7]) {
    static const uint8_t PAGE_FOUR[4] = {0xA5, 0x83, 0xF6, 0x00};
    size_t length = write_header(out, 21, uid, PAGE_FOUR, 17);

    out[length++] = 2;
    out[length++] = 5;
    out[length++] = 8;
    memset(&out[length], 0x11, 8);
    length += 8;
    out[length++] = 48;
    out[length++] = 12;
    memset(&out[length], 0x22, 12);
    return length + 12;
}

static inline size_t build_slot_write(uint8_t *out, const uint8_t uid[7]) {
    static const uint8_t SLOT_HEADER[4] = {0xA5, 0x00, 0x04, 0x00};
    size_t length = write_header(out, 22, uid, SLOT_HEADER, 18);

    out[length++] = 2;
    out[length++] = 0;
    out[length++] = 0x92;
    out[length++] = 8;
    memset(&out[length], 0x33, 8);
    length += 8;
    out[length++] = 1;
    out[length++] = 1;
    out[length++] = 12;
    memset(&out[length], 0x44, 12);
    return length + 12;
}

#endif
