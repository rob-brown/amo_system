#ifndef NFC_NFC_SESSION_H
#define NFC_NFC_SESSION_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nfc/amiibo_store.h"
#include "nfc/nfc_buffer.h"
#include "nfc/nfc_write.h"

#define NFC_BUFFER_CAPACITY 2400
#define NFC_READ_CHUNK_SIZE 69
#define NFC_POLL_REPLY_SIZE 61
#define NFC_READ_REPLY_SIZE (3 + NFC_READ_CHUNK_SIZE)
#define NFC_EVENT_COUNTER_MASK 0x07
#define NFC_FIRST_CONFIGURE_DELAY_MS 1100
#define NFC_REPEAT_CONFIGURE_DELAY_MS 50
#define NFC_PHASE_DELAY_MS 80

typedef enum {
    NFC_STATE_IDLE,
    NFC_STATE_READING,
    NFC_STATE_SRAM,
    NFC_STATE_REGISTRY,
    NFC_STATE_SLOT_WRITTEN,
    NFC_STATE_WRITE_DONE,
    NFC_STATE_WRITE_REFUSED
} nfc_state_t;

typedef struct {
    void (*on_read_started)(void *context);
    void (*on_write_started)(void *context);
    void (*on_write_finished)(void *context, bool succeeded);
    void *context;
} nfc_session_listener_t;

typedef struct {
    amiibo_store_t *amiibo;
    nfc_session_listener_t listener;
    nfc_state_t state;
    bool configured;
    uint32_t seen_generation;
    nfc_write_buffer_t write;
    uint8_t buffer[NFC_BUFFER_CAPACITY];
    size_t buffer_length;
    uint8_t event_counter;
    bool event_pending;
    uint32_t event_delay_ms;
} nfc_session_t;

void nfc_session_init(nfc_session_t *session, amiibo_store_t *amiibo);

void nfc_session_set_listener(nfc_session_t *session, const nfc_session_listener_t *listener);

void nfc_session_configure(nfc_session_t *session, const uint8_t *payload, size_t length);

void nfc_session_tick(nfc_session_t *session, uint32_t elapsed_ms);

uint8_t nfc_session_event_counter(const nfc_session_t *session);

void nfc_session_end(nfc_session_t *session);

size_t nfc_session_poll(const nfc_session_t *session, uint8_t *out, size_t capacity);

bool nfc_session_start_read(nfc_session_t *session, const uint8_t *payload, size_t length);

bool nfc_session_add_write_piece(nfc_session_t *session, const uint8_t *payload, size_t length);

bool nfc_session_commit_write(nfc_session_t *session);

bool nfc_session_commit_slots(nfc_session_t *session);

bool nfc_session_finish_write(nfc_session_t *session);

bool nfc_session_read_registry(nfc_session_t *session, const uint8_t *payload, size_t length);

size_t nfc_session_read(const nfc_session_t *session, const uint8_t *payload, size_t length, uint8_t *out, size_t capacity);

#endif
