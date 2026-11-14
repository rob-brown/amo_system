#ifndef PROTOCOL_HANDLERS_NFC_COMMANDS_H
#define PROTOCOL_HANDLERS_NFC_COMMANDS_H

#include "protocol/command_router.h"

#define NFC_COMMAND 0x01
#define NFC_SUBCOMMAND_CONFIGURE 0x03
#define NFC_SUBCOMMAND_END 0x04
#define NFC_SUBCOMMAND_POLL 0x05
#define NFC_SUBCOMMAND_START_READ 0x06
#define NFC_SUBCOMMAND_WRITE 0x14
#define NFC_SUBCOMMAND_READ 0x15
#define NFC_SUBCOMMAND_COMMIT_WRITE 0x21
#define NFC_SUBCOMMAND_READ_REGISTRY 0x1E

size_t nfc_configure_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity);

size_t nfc_end_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity);

size_t nfc_poll_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity);

size_t nfc_start_read_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity);

size_t nfc_read_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity);

size_t nfc_write_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity);

size_t nfc_commit_write_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity);

size_t nfc_read_registry_handle(void *context, const command_request_t *request, uint8_t *payload, size_t capacity);

#endif
