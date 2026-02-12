#ifndef SWITCH_EMULATOR_H
#define SWITCH_EMULATOR_H

#include <stdint.h>
#include <stdbool.h>
#include "btstack.h"

typedef enum {
    EMULATOR_STATE_IDLE,
    EMULATOR_STATE_SCANNING,
    EMULATOR_STATE_CONNECTING,
    EMULATOR_STATE_READY
} emulator_state_t;

void switch_emulator_init(void);
void switch_emulator_start_scan(void);
void switch_emulator_stop_scan(void);
emulator_state_t switch_emulator_get_state(void);
bool switch_emulator_is_connected(void);

int switch_emulator_main(void);

#endif
