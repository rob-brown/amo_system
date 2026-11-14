#ifndef APP_APP_H
#define APP_APP_H

#include "ble/ble_peripheral.h"
#include "host/host_commands.h"
#include "platform/host_transport.h"
#include "storage/pairing_store.h"

typedef struct {
    const pairing_store_t *pairing_store;
    ble_platform_t ble;
    host_transport_t host;
    host_system_t system;
} app_platform_t;

int app_run(const app_platform_t *platform);

#endif
