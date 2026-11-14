#include "ble/gatt_bridge.h"

#include <string.h>

#include "ble/gatt_handles.h"
#include "platform/log.h"
#include "protocol/reply_queue.h"

#define INPUT_REPORT_CAPACITY 64

typedef struct {
    gatt_bridge_listener_t listener;
    hci_con_handle_t connection;
    bool reply_notifications_enabled;
    reply_queue_t replies;
    bool input_notifications_enabled;
    bool input_pending;
    uint8_t input_report[INPUT_REPORT_CAPACITY];
    size_t input_length;
} gatt_bridge_state_t;

static gatt_bridge_state_t state;

static bool reply_ready(void) {
    return state.reply_notifications_enabled && !reply_queue_is_empty(&state.replies);
}

static bool input_ready(void) {
    return state.input_notifications_enabled && state.input_pending;
}

static void request_send_if_pending(void) {
    if (state.connection == HCI_CON_HANDLE_INVALID) {
        return;
    }
    if (reply_ready() || input_ready()) {
        att_server_request_can_send_now_event(state.connection);
    }
}

static void send_next_reply(void) {
    size_t length = 0;
    const uint8_t *frame = reply_queue_peek(&state.replies, &length);

    uint8_t status = att_server_notify(state.connection, HANDLE_COMMAND_REPLY, frame, (uint16_t)length);
    if (status != ERROR_CODE_SUCCESS) {
        LOG("reply notify failed: 0x%02x", status);
        return;
    }

    reply_queue_pop(&state.replies);
}

static void send_input_report(void) {
    uint8_t status = att_server_notify(state.connection, HANDLE_INPUT_REPORT, state.input_report,
                                       (uint16_t)state.input_length);
    if (status != ERROR_CODE_SUCCESS) {
        LOG("input notify failed: 0x%02x", status);
        return;
    }

    state.input_pending = false;
}

static void send_next(void) {
    if (reply_ready()) {
        send_next_reply();
    } else if (input_ready()) {
        send_input_report();
    }
    request_send_if_pending();
}

static void reset_connection_state(hci_con_handle_t connection) {
    state.connection = connection;
    state.reply_notifications_enabled = false;
    state.input_notifications_enabled = false;
    state.input_pending = false;
    reply_queue_init(&state.replies);
}

static bool notifications_enabled(const uint8_t *buffer) {
    return little_endian_read_16(buffer, 0) == GATT_CLIENT_CHARACTERISTICS_CONFIGURATION_NOTIFICATION;
}

void gatt_bridge_init(const gatt_bridge_listener_t *listener) {
    state.listener = *listener;
    reset_connection_state(HCI_CON_HANDLE_INVALID);
}

void gatt_bridge_connected(hci_con_handle_t connection) {
    reset_connection_state(connection);
}

void gatt_bridge_disconnected(void) {
    reset_connection_state(HCI_CON_HANDLE_INVALID);
}

bool gatt_bridge_send_reply(const uint8_t *frame, size_t length) {
    if (!reply_queue_push(&state.replies, frame, length)) {
        LOG("reply queue full, dropping %u bytes", (unsigned)length);
        return false;
    }

    request_send_if_pending();
    return true;
}

bool gatt_bridge_input_enabled(void) {
    return state.connection != HCI_CON_HANDLE_INVALID && state.input_notifications_enabled;
}

bool gatt_bridge_send_input_report(const uint8_t *report, size_t length) {
    if (length > INPUT_REPORT_CAPACITY) {
        return false;
    }

    memcpy(state.input_report, report, length);
    state.input_length = length;
    state.input_pending = true;
    request_send_if_pending();
    return true;
}

uint16_t gatt_bridge_read(hci_con_handle_t connection,
                          uint16_t attribute_handle,
                          uint16_t offset,
                          uint8_t *buffer,
                          uint16_t buffer_size) {
    UNUSED(connection);
    UNUSED(attribute_handle);

    return att_read_callback_handle_blob(NULL, 0, offset, buffer, buffer_size);
}

int gatt_bridge_write(hci_con_handle_t connection,
                      uint16_t attribute_handle,
                      uint16_t transaction_mode,
                      uint16_t offset,
                      uint8_t *buffer,
                      uint16_t buffer_size) {
    UNUSED(connection);
    UNUSED(transaction_mode);
    UNUSED(offset);

    if (attribute_handle == HANDLE_COMMAND_WRITE) {
        state.listener.on_command_write(state.listener.context, buffer, buffer_size);
        return 0;
    }

    if (attribute_handle == HANDLE_COMMAND_REPLY_CCC) {
        state.reply_notifications_enabled = notifications_enabled(buffer);
        LOG("reply notifications %s", state.reply_notifications_enabled ? "enabled" : "disabled");
        request_send_if_pending();
        return 0;
    }

    if (attribute_handle == HANDLE_INPUT_REPORT_CCC) {
        state.input_notifications_enabled = notifications_enabled(buffer);
        LOG("input notifications %s", state.input_notifications_enabled ? "enabled" : "disabled");
        request_send_if_pending();
        return 0;
    }

    LOG("write to handle 0x%04x ignored (%u bytes)", attribute_handle, buffer_size);
    return 0;
}

void gatt_bridge_handle_att_event(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size) {
    UNUSED(channel);
    UNUSED(size);

    if (packet_type != HCI_EVENT_PACKET) {
        return;
    }

    switch (hci_event_packet_get_type(packet)) {
    case ATT_EVENT_CAN_SEND_NOW:
        send_next();
        break;
    case ATT_EVENT_MTU_EXCHANGE_COMPLETE:
        LOG("ATT MTU %u", att_event_mtu_exchange_complete_get_MTU(packet));
        break;
    default:
        break;
    }
}
