#include "nfc/nfc_session.h"

#include <string.h>

#define CONFIGURE_TIMER_START 1
#define CONFIGURE_TIMER_END 3
#define REQUEST_ECHO_OFFSET 10
#define MIN_ECHO_SIZE 3
#define POLL_TAG_COUNT_OFFSET 4

static void schedule_event(nfc_session_t *session, uint32_t delay_ms) {
    session->event_pending = true;
    session->event_delay_ms = delay_ms;
}

static bool enter_phase(nfc_session_t *session, nfc_state_t state, size_t buffer_length) {
    if (buffer_length == 0) {
        return false;
    }

    session->buffer_length = buffer_length;
    session->state = state;
    schedule_event(session, NFC_PHASE_DELAY_MS);
    return true;
}

static uint8_t poll_status(const nfc_session_t *session) {
    switch (session->state) {
    case NFC_STATE_READING:
        return NFC_STATUS_READ_READY;
    case NFC_STATE_SRAM:
        return NFC_STATUS_SRAM_READY;
    case NFC_STATE_REGISTRY:
        return NFC_STATUS_REGISTRY_READY;
    case NFC_STATE_SLOT_WRITTEN:
        return NFC_STATUS_SLOT_WRITTEN;
    case NFC_STATE_WRITE_DONE:
        return NFC_STATUS_WRITE_DONE;
    case NFC_STATE_WRITE_REFUSED:
        return NFC_STATUS_TAG_LOST;
    case NFC_STATE_IDLE:
    default:
        return NFC_STATUS_TAG_FOUND;
    }
}

static bool is_status_only_state(nfc_state_t state) {
    return state == NFC_STATE_SRAM || state == NFC_STATE_REGISTRY || state == NFC_STATE_SLOT_WRITTEN || state == NFC_STATE_WRITE_DONE ||
           state == NFC_STATE_WRITE_REFUSED;
}

static void enter_write_state(nfc_session_t *session, nfc_state_t state) {
    session->state = state;
    session->buffer_length = 0;
    nfc_write_buffer_reset(&session->write);
    schedule_event(session, NFC_PHASE_DELAY_MS);
}

void nfc_session_init(nfc_session_t *session, amiibo_store_t *amiibo) {
    memset(session, 0, sizeof(*session));
    session->amiibo = amiibo;
    session->state = NFC_STATE_IDLE;
    session->seen_generation = amiibo->generation;
}

void nfc_session_set_listener(nfc_session_t *session, const nfc_session_listener_t *listener) {
    session->listener = *listener;
}

void nfc_session_configure(nfc_session_t *session, const uint8_t *payload, size_t length) {
    session->configured = true;
    if (!amiibo_store_is_loaded(session->amiibo)) {
        return;
    }

    bool first_configure = length >= CONFIGURE_TIMER_END && payload[CONFIGURE_TIMER_START] == 0 && payload[CONFIGURE_TIMER_START + 1] == 0;
    schedule_event(session, first_configure ? NFC_FIRST_CONFIGURE_DELAY_MS : NFC_REPEAT_CONFIGURE_DELAY_MS);
}

void nfc_session_tick(nfc_session_t *session, uint32_t elapsed_ms) {
    if (session->amiibo->generation != session->seen_generation) {
        session->seen_generation = session->amiibo->generation;
        if (session->configured && session->amiibo->state != AMIIBO_STORE_LOADING) {
            schedule_event(session, NFC_REPEAT_CONFIGURE_DELAY_MS);
        }
    }

    if (!session->event_pending) {
        return;
    }

    if (session->event_delay_ms > elapsed_ms) {
        session->event_delay_ms -= elapsed_ms;
        return;
    }
    session->event_pending = false;
    session->event_delay_ms = 0;
    session->event_counter = (uint8_t)((session->event_counter + 1) & NFC_EVENT_COUNTER_MASK);
}

uint8_t nfc_session_event_counter(const nfc_session_t *session) {
    return session->event_counter;
}

void nfc_session_end(nfc_session_t *session) {
    session->configured = false;
    nfc_write_buffer_reset(&session->write);
    session->state = NFC_STATE_IDLE;
    session->buffer_length = 0;
    session->event_pending = false;
}

size_t nfc_session_poll(nfc_session_t *session, uint8_t *out, size_t capacity) {
    if (capacity < NFC_POLL_REPLY_SIZE) {
        return 0;
    }

    memset(out, 0, NFC_POLL_REPLY_SIZE);
    if (!amiibo_store_is_loaded(session->amiibo)) {
        out[0] = session->tag_reported ? NFC_STATUS_TAG_LOST : NFC_STATUS_NO_TAG;
        out[1] = session->tag_reported ? NFC_TAG_LOST_DETAIL : 0;
        session->tag_reported = false;
        return NFC_POLL_REPLY_SIZE;
    }

    session->tag_reported = true;
    out[0] = poll_status(session);
    if (is_status_only_state(session->state)) {
        return NFC_POLL_REPLY_SIZE;
    }

    out[POLL_TAG_COUNT_OFFSET] = 0x01;
    nfc_write_tag_info(&out[POLL_TAG_COUNT_OFFSET + 1], session->amiibo);
    return NFC_POLL_REPLY_SIZE;
}

bool nfc_session_start_read(nfc_session_t *session, const uint8_t *payload, size_t length) {
    if (!amiibo_store_is_loaded(session->amiibo) || length < REQUEST_ECHO_OFFSET + MIN_ECHO_SIZE) {
        return false;
    }

    size_t built = nfc_build_range_buffer(session->amiibo, &payload[REQUEST_ECHO_OFFSET], length - REQUEST_ECHO_OFFSET, session->buffer,
                                          sizeof(session->buffer));
    if (!enter_phase(session, NFC_STATE_READING, built)) {
        return false;
    }
    if (session->listener.on_read_started != NULL) {
        session->listener.on_read_started(session->listener.context);
    }
    return true;
}

bool nfc_session_add_write_piece(nfc_session_t *session, const uint8_t *payload, size_t length) {
    return amiibo_store_is_loaded(session->amiibo) && nfc_write_buffer_add_piece(&session->write, payload, length);
}

bool nfc_session_commit_write(nfc_session_t *session) {
    nfc_write_buffer_reset(&session->write);
    return enter_phase(session, NFC_STATE_SRAM, nfc_build_sram_buffer(session->amiibo, session->buffer, sizeof(session->buffer)));
}

bool nfc_session_commit_slots(nfc_session_t *session) {
    if (session->listener.on_write_started != NULL) {
        session->listener.on_write_started(session->listener.context);
    }

    bool applied = !session->amiibo->readonly && nfc_write_apply_slots(&session->write, session->amiibo);
    enter_write_state(session, applied ? NFC_STATE_SLOT_WRITTEN : NFC_STATE_WRITE_REFUSED);
    return applied;
}

bool nfc_session_finish_write(nfc_session_t *session) {
    bool applied = !session->amiibo->readonly && nfc_write_apply_app_data(&session->write, session->amiibo);

    enter_write_state(session, applied ? NFC_STATE_WRITE_DONE : NFC_STATE_WRITE_REFUSED);
    if (session->listener.on_write_finished != NULL) {
        session->listener.on_write_finished(session->listener.context, applied);
    }
    return applied;
}

bool nfc_session_read_registry(nfc_session_t *session, const uint8_t *payload, size_t length) {
    if (session->state != NFC_STATE_SRAM || length <= REQUEST_ECHO_OFFSET) {
        return false;
    }

    size_t built = nfc_build_registry_buffer(session->amiibo, &payload[REQUEST_ECHO_OFFSET], length - REQUEST_ECHO_OFFSET, session->buffer,
                                             sizeof(session->buffer));
    return enter_phase(session, NFC_STATE_REGISTRY, built);
}

size_t nfc_session_read(const nfc_session_t *session, const uint8_t *payload, size_t length, uint8_t *out, size_t capacity) {
    if (session->state == NFC_STATE_IDLE || length < 2 || capacity < NFC_READ_REPLY_SIZE) {
        return 0;
    }

    size_t offset = (size_t)payload[0] | ((size_t)payload[1] << 8);
    if (offset >= session->buffer_length) {
        return 0;
    }

    size_t remaining = session->buffer_length - offset;
    size_t chunk = remaining < NFC_READ_CHUNK_SIZE ? remaining : NFC_READ_CHUNK_SIZE;
    memset(out, 0, NFC_READ_REPLY_SIZE);
    out[0] = chunk == remaining ? 1 : 0;
    out[1] = (uint8_t)(chunk & 0xFF);
    out[2] = (uint8_t)(chunk >> 8);
    memcpy(&out[3], &session->buffer[offset], chunk);
    return NFC_READ_REPLY_SIZE;
}
