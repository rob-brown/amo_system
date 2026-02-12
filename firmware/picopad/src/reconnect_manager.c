#include "reconnect_manager.h"
#include "logging.h"
#include "pico/stdlib.h"
#include <string.h>
#include <stdio.h>

typedef struct {
    bool active;
    bd_addr_t target_addr;
    reconnect_policy_t policy;
    uint8_t current_attempt;
    btstack_timer_source_t retry_timer;
    reconnect_callback_t callback;
    bool timer_active;
} reconnect_state_t;

static reconnect_state_t state;

static void retry_timer_handler(btstack_timer_source_t *ts);

void reconnect_manager_init(void) {
    memset(&state, 0, sizeof(state));
}

static uint16_t calculate_retry_interval(void) {
    if (!state.policy.use_exponential_backoff) {
        return state.policy.base_interval_ms;
    }

    uint16_t interval = state.policy.base_interval_ms;
    for (uint8_t i = 1; i < state.current_attempt && i < 4; i++) {
        interval *= 2;
        if (interval > 10000) {
            interval = 10000;
        }
    }

    return interval;
}

static void schedule_retry(void) {
    if (state.current_attempt >= state.policy.max_attempts) {
        pico_log_criticalf("Reconnect: max attempts reached (%d)", state.policy.max_attempts);
        state.active = false;
        state.timer_active = false;

        if (state.callback) {
            state.callback(false, state.current_attempt);
        }
        return;
    }

    uint16_t interval = calculate_retry_interval();
    pico_log_noticef("Reconnect: scheduling retry %d/%d in %dms",
              state.current_attempt + 1, state.policy.max_attempts, interval);

    btstack_run_loop_remove_timer(&state.retry_timer);
    btstack_run_loop_set_timer_handler(&state.retry_timer, retry_timer_handler);
    btstack_run_loop_set_timer(&state.retry_timer, interval);
    btstack_run_loop_add_timer(&state.retry_timer);
    state.timer_active = true;
}

static void retry_timer_handler(btstack_timer_source_t *ts) {
    UNUSED(ts);

    state.timer_active = false;

    if (!state.active) {
        return;
    }

    state.current_attempt++;
    pico_log_noticef("Reconnect: attempt %d/%d to %s",
              state.current_attempt, state.policy.max_attempts,
              bd_addr_to_str(state.target_addr));

    if (state.callback) {
        state.callback(false, state.current_attempt);
    }
}

void reconnect_manager_start(bd_addr_t target, reconnect_policy_t policy, reconnect_callback_t callback) {
    if (state.active) {
        pico_log_notice("Reconnect: stopping existing reconnection");
        reconnect_manager_stop();
    }

    pico_log_noticef("Reconnect: starting with policy type %d (max=%d, interval=%dms)",
              policy.type, policy.max_attempts, policy.base_interval_ms);

    memcpy(state.target_addr, target, 6);
    state.policy = policy;
    state.current_attempt = 1;
    state.active = true;
    state.callback = callback;
    state.timer_active = false;

    pico_log_noticef("Reconnect: attempt 1/%d to %s",
              policy.max_attempts, bd_addr_to_str(target));
}

void reconnect_manager_stop(void) {
    if (state.timer_active) {
        btstack_run_loop_remove_timer(&state.retry_timer);
        state.timer_active = false;
    }
    state.active = false;
    pico_log_notice("Reconnect: stopped");
}

void reconnect_manager_on_success(void) {
    if (!state.active) {
        return;
    }

    pico_log_noticef("Reconnect: succeeded on attempt %d", state.current_attempt);

    if (state.timer_active) {
        btstack_run_loop_remove_timer(&state.retry_timer);
        state.timer_active = false;
    }

    reconnect_callback_t cb = state.callback;
    uint8_t attempts = state.current_attempt;

    state.active = false;

    if (cb) {
        cb(true, attempts);
    }
}

void reconnect_manager_on_failure(uint8_t error_code) {
    if (!state.active) {
        return;
    }

    pico_log_warningf("Reconnect: attempt %d failed with error 0x%02x",
                 state.current_attempt, error_code);

    schedule_retry();
}

bool reconnect_manager_is_active(void) {
    return state.active;
}

uint8_t reconnect_manager_get_attempt_count(void) {
    return state.current_attempt;
}
