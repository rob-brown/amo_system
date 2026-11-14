#ifndef PROTOCOL_COMMAND_SET_H
#define PROTOCOL_COMMAND_SET_H

#include <stdbool.h>

#include "controller/identity.h"
#include "nfc/nfc_session.h"
#include "protocol/command_router.h"
#include "protocol/pairing.h"

#define COMMAND_SET_MAX_ROUTES 32

typedef struct {
    command_route_t routes[COMMAND_SET_MAX_ROUTES];
    command_router_t router;
} command_set_t;

bool command_set_init(command_set_t *set, const controller_identity_t *identity, pairing_t *pairing);

bool command_set_add_nfc(command_set_t *set, nfc_session_t *nfc);

#endif
