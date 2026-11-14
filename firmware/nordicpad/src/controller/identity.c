#include "controller/identity.h"

#define ERASED_FLASH_BYTE 0xFF

static const memory_region_t *find_region(const controller_identity_t *identity, uint32_t address) {
    for (size_t index = 0; index < identity->memory_region_count; index++) {
        const memory_region_t *region = &identity->memory_regions[index];
        if (address >= region->address && address - region->address < region->length) {
            return region;
        }
    }
    return NULL;
}

void identity_read_memory(const controller_identity_t *identity,
                          uint32_t address,
                          size_t length,
                          uint8_t *output) {
    for (size_t index = 0; index < length; index++) {
        const memory_region_t *region = find_region(identity, address + (uint32_t)index);
        output[index] = (region == NULL)
                            ? ERASED_FLASH_BYTE
                            : region->data[address + (uint32_t)index - region->address];
    }
}

const static_reply_t *identity_find_static_reply(const controller_identity_t *identity,
                                                 uint8_t command,
                                                 uint8_t subcommand) {
    for (size_t index = 0; index < identity->static_reply_count; index++) {
        const static_reply_t *reply = &identity->static_replies[index];
        if (reply->command == command && reply->subcommand == subcommand) {
            return reply;
        }
    }
    return NULL;
}
