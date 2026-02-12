#ifndef RECONNECT_MANAGER_H
#define RECONNECT_MANAGER_H

#include <stdbool.h>
#include <stdint.h>
#include "btstack.h"

typedef enum {
    RECONNECT_POLICY_AUTO,
    RECONNECT_POLICY_USER,
    RECONNECT_POLICY_BOOT
} reconnect_policy_type_t;

typedef struct {
    reconnect_policy_type_t type;
    uint8_t max_attempts;
    uint16_t base_interval_ms;
    bool use_exponential_backoff;
} reconnect_policy_t;

typedef void (*reconnect_callback_t)(bool success, uint8_t attempts);

void reconnect_manager_init(void);

void reconnect_manager_start(bd_addr_t target, reconnect_policy_t policy, reconnect_callback_t callback);

void reconnect_manager_stop(void);

void reconnect_manager_on_success(void);

void reconnect_manager_on_failure(uint8_t error_code);

bool reconnect_manager_is_active(void);

uint8_t reconnect_manager_get_attempt_count(void);

#endif
