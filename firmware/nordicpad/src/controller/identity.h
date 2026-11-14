#ifndef CONTROLLER_IDENTITY_H
#define CONTROLLER_IDENTITY_H

#include <stddef.h>
#include <stdint.h>

typedef struct {
    uint32_t address;
    uint16_t length;
    const uint8_t *data;
} memory_region_t;

typedef struct {
    uint8_t command;
    uint8_t subcommand;
    const uint8_t *payload;
    size_t payload_length;
} static_reply_t;

typedef struct {
    const memory_region_t *memory_regions;
    size_t memory_region_count;
    const static_reply_t *static_replies;
    size_t static_reply_count;
} controller_identity_t;

extern const controller_identity_t CONTROLLER_IDENTITY;

void identity_read_memory(const controller_identity_t *identity,
                          uint32_t address,
                          size_t length,
                          uint8_t *output);

const static_reply_t *identity_find_static_reply(const controller_identity_t *identity,
                                                 uint8_t command,
                                                 uint8_t subcommand);

#endif
