#ifndef PROTOCOL_HANDLERS_PAIRING_COMMANDS_H
#define PROTOCOL_HANDLERS_PAIRING_COMMANDS_H

#include "protocol/command_router.h"

#define PAIRING_COMMAND 0x15
#define PAIRING_SUBCOMMAND_HOST_ADDRESSES 0x01
#define PAIRING_SUBCOMMAND_CHALLENGE 0x02
#define PAIRING_SUBCOMMAND_FINALISE 0x03
#define PAIRING_SUBCOMMAND_KEY_EXCHANGE 0x04

size_t pairing_host_addresses_handle(void *context,
                                     const command_request_t *request,
                                     uint8_t *payload,
                                     size_t capacity);

size_t pairing_key_exchange_handle(void *context,
                                   const command_request_t *request,
                                   uint8_t *payload,
                                   size_t capacity);

size_t pairing_challenge_handle(void *context,
                                const command_request_t *request,
                                uint8_t *payload,
                                size_t capacity);

size_t pairing_finalise_handle(void *context,
                               const command_request_t *request,
                               uint8_t *payload,
                               size_t capacity);

#endif
