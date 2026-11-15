#include "protocol/command_set.h"

#include "protocol/handlers/memory_read.h"
#include "protocol/handlers/nfc_commands.h"
#include "protocol/handlers/pairing_commands.h"
#include "protocol/handlers/static_reply.h"

static bool add_route(command_set_t *set, command_route_t route) {
    if (set->router.route_count >= COMMAND_SET_MAX_ROUTES) {
        return false;
    }

    set->routes[set->router.route_count++] = route;
    return true;
}

static bool add_static_replies(command_set_t *set, const controller_identity_t *identity) {
    for (size_t index = 0; index < identity->static_reply_count; index++) {
        const static_reply_t *reply = &identity->static_replies[index];
        command_route_t route = {
            .command = reply->command,
            .subcommand = reply->subcommand,
            .handler = static_reply_handle,
            .context = (void *)reply,
        };

        if (!add_route(set, route)) {
            return false;
        }
    }
    return true;
}

static bool add_pairing_routes(command_set_t *set, pairing_t *pairing) {
    const command_route_t routes[] = {
        {PAIRING_COMMAND, PAIRING_SUBCOMMAND_HOST_ADDRESSES, pairing_host_addresses_handle, pairing},
        {PAIRING_COMMAND, PAIRING_SUBCOMMAND_KEY_EXCHANGE, pairing_key_exchange_handle, pairing},
        {PAIRING_COMMAND, PAIRING_SUBCOMMAND_CHALLENGE, pairing_challenge_handle, pairing},
        {PAIRING_COMMAND, PAIRING_SUBCOMMAND_FINALISE, pairing_finalise_handle, pairing},
    };

    for (size_t index = 0; index < sizeof(routes) / sizeof(routes[0]); index++) {
        if (!add_route(set, routes[index])) {
            return false;
        }
    }
    return true;
}

bool command_set_init(command_set_t *set, const controller_identity_t *identity, pairing_t *pairing) {
    set->router.routes = set->routes;
    set->router.route_count = 0;

    command_route_t memory_route = {
        .command = MEMORY_READ_COMMAND,
        .subcommand = MEMORY_READ_SUBCOMMAND,
        .handler = memory_read_handle,
        .context = (void *)identity,
    };

    return add_route(set, memory_route) && add_static_replies(set, identity) &&
           add_pairing_routes(set, pairing);
}

bool command_set_add_nfc(command_set_t *set, nfc_session_t *nfc) {
    const command_route_t routes[] = {
        {NFC_COMMAND, NFC_SUBCOMMAND_CONFIGURE, nfc_configure_handle, nfc},
        {NFC_COMMAND, NFC_SUBCOMMAND_END, nfc_end_handle, nfc},
        {NFC_COMMAND, NFC_SUBCOMMAND_POLL, nfc_poll_handle, nfc},
        {NFC_COMMAND, NFC_SUBCOMMAND_START_READ, nfc_start_read_handle, nfc},
        {NFC_COMMAND, NFC_SUBCOMMAND_READ, nfc_read_handle, nfc},
        {NFC_COMMAND, NFC_SUBCOMMAND_FINISH_WRITE, nfc_finish_write_handle, nfc},
        {NFC_COMMAND, NFC_SUBCOMMAND_WRITE, nfc_write_handle, nfc},
        {NFC_COMMAND, NFC_SUBCOMMAND_COMMIT_SLOTS, nfc_commit_slots_handle, nfc},
        {NFC_COMMAND, NFC_SUBCOMMAND_COMMIT_WRITE, nfc_commit_write_handle, nfc},
        {NFC_COMMAND, NFC_SUBCOMMAND_READ_REGISTRY, nfc_read_registry_handle, nfc},
    };

    for (size_t index = 0; index < sizeof(routes) / sizeof(routes[0]); index++) {
        if (!add_route(set, routes[index])) {
            return false;
        }
    }
    return true;
}
