#ifndef CONTROLLER_PROFILE_IDENTITY_H
#define CONTROLLER_PROFILE_IDENTITY_H

#include <stdbool.h>

#include "controller/identity.h"
#include "controller/profile.h"

#define PROFILE_IDENTITY_MAX_REGIONS 16
#define PROFILE_IDENTITY_MAX_REPLIES 32
#define PROFILE_IDENTITY_FACTORY_SIZE 64
#define PROFILE_IDENTITY_REPLY_SIZE 32
#define PROFILE_IDENTITY_CALIBRATION_SIZE 64

typedef struct {
    controller_identity_t identity;
    memory_region_t regions[PROFILE_IDENTITY_MAX_REGIONS];
    static_reply_t replies[PROFILE_IDENTITY_MAX_REPLIES];
    uint8_t factory[PROFILE_IDENTITY_FACTORY_SIZE];
    uint8_t firmware_info[PROFILE_IDENTITY_REPLY_SIZE];
    uint8_t secondary_calibration[PROFILE_IDENTITY_CALIBRATION_SIZE];
} profile_identity_t;

bool profile_identity_build(profile_identity_t *result, const controller_identity_t *base,
                            const controller_profile_t *profile);

void profile_identity_set_colors(profile_identity_t *identity, const controller_colors_t *colors);

#endif
