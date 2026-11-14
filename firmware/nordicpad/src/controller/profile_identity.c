#include "controller/profile_identity.h"

#include <string.h>

#define FACTORY_BASE 0x00013000u
#define PRODUCT_ID_OFFSET 0x14
#define HARDWARE_VARIANT_OFFSET 0x16
#define SERIAL_OFFSET 0x02
#define COLORS_OFFSET 0x19
#define PRIMARY_CALIBRATION_ADDRESS 0x00013080u
#define SECONDARY_CALIBRATION_ADDRESS 0x000130C0u
#define FIRMWARE_INFO_COMMAND 0x10
#define FIRMWARE_INFO_SUBCOMMAND 0x01
#define FIRMWARE_INFO_TYPE_OFFSET 3
#define FIRMWARE_INFO_DSP_OFFSET 8

static bool copy_memory_regions(profile_identity_t *result, const controller_identity_t *base) {
    if (base->memory_region_count + 1 > PROFILE_IDENTITY_MAX_REGIONS) {
        return false;
    }
    for (size_t index = 0; index < base->memory_region_count; index++) {
        const memory_region_t *region = &base->memory_regions[index];
        result->regions[index] = *region;
        if (region->address == FACTORY_BASE) {
            if (region->length > PROFILE_IDENTITY_FACTORY_SIZE) {
                return false;
            }
            memcpy(result->factory, region->data, region->length);
            result->regions[index].data = result->factory;
        }
    }
    result->identity.memory_regions = result->regions;
    result->identity.memory_region_count = base->memory_region_count;
    return true;
}

static bool copy_static_replies(profile_identity_t *result, const controller_identity_t *base,
                                const controller_profile_t *profile) {
    if (base->static_reply_count + profile->extra_reply_count > PROFILE_IDENTITY_MAX_REPLIES) {
        return false;
    }
    for (size_t index = 0; index < base->static_reply_count; index++) {
        const static_reply_t *reply = &base->static_replies[index];
        result->replies[index] = *reply;
        bool is_firmware_info = reply->command == FIRMWARE_INFO_COMMAND && reply->subcommand == FIRMWARE_INFO_SUBCOMMAND;
        if (is_firmware_info) {
            if (reply->payload_length > PROFILE_IDENTITY_REPLY_SIZE ||
                reply->payload_length < FIRMWARE_INFO_DSP_OFFSET + VERSION_SIZE) {
                return false;
            }
            memcpy(result->firmware_info, reply->payload, reply->payload_length);
            result->firmware_info[FIRMWARE_INFO_TYPE_OFFSET] = (uint8_t)profile->type;
            memcpy(&result->firmware_info[FIRMWARE_INFO_DSP_OFFSET], profile->dsp_firmware_version, VERSION_SIZE);
            result->replies[index].payload = result->firmware_info;
        }
    }
    memcpy(&result->replies[base->static_reply_count], profile->extra_replies,
           profile->extra_reply_count * sizeof(static_reply_t));
    result->identity.static_replies = result->replies;
    result->identity.static_reply_count = base->static_reply_count + profile->extra_reply_count;
    return true;
}

static void add_secondary_calibration(profile_identity_t *result, const controller_identity_t *base,
                                      const controller_profile_t *profile) {
    if (profile->input_layout->left_stick_offset == STICK_ABSENT) {
        return;
    }
    identity_read_memory(base, PRIMARY_CALIBRATION_ADDRESS, PROFILE_IDENTITY_CALIBRATION_SIZE,
                         result->secondary_calibration);
    result->regions[result->identity.memory_region_count++] = (memory_region_t){
        SECONDARY_CALIBRATION_ADDRESS, PROFILE_IDENTITY_CALIBRATION_SIZE, result->secondary_calibration};
}

static bool apply_memory_overrides(profile_identity_t *result, const controller_profile_t *profile) {
    for (size_t index = 0; index < profile->memory_override_count; index++) {
        const memory_region_t *override = &profile->memory_overrides[index];
        size_t slot = 0;
        while (slot < result->identity.memory_region_count && result->regions[slot].address != override->address) {
            slot++;
        }
        if (slot == result->identity.memory_region_count) {
            if (slot >= PROFILE_IDENTITY_MAX_REGIONS) {
                return false;
            }
            result->identity.memory_region_count++;
        }
        result->regions[slot] = *override;
    }
    return true;
}

bool profile_identity_build(profile_identity_t *result, const controller_identity_t *base,
                            const controller_profile_t *profile) {
    memset(result, 0, sizeof(*result));
    if (!copy_memory_regions(result, base) || !copy_static_replies(result, base, profile)) {
        return false;
    }
    result->factory[PRODUCT_ID_OFFSET] = (uint8_t)(profile->product_id & 0xFF);
    result->factory[PRODUCT_ID_OFFSET + 1] = (uint8_t)(profile->product_id >> 8);
    memcpy(&result->factory[HARDWARE_VARIANT_OFFSET], profile->hardware_variant, VERSION_SIZE);
    memcpy(&result->factory[SERIAL_OFFSET], profile->serial_prefix, sizeof(profile->serial_prefix));
    if (profile->serial_digits[0] != 0) {
        memcpy(&result->factory[SERIAL_OFFSET + sizeof(profile->serial_prefix)], profile->serial_digits,
               sizeof(profile->serial_digits));
    }
    add_secondary_calibration(result, base, profile);
    if (!apply_memory_overrides(result, profile)) {
        return false;
    }
    profile_identity_set_colors(result, &profile->colors);
    return true;
}

void profile_identity_set_colors(profile_identity_t *identity, const controller_colors_t *colors) {
    memcpy(&identity->factory[COLORS_OFFSET], colors, sizeof(*colors));
}
