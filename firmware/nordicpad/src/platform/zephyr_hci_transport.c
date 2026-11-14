#include "platform/zephyr_hci_transport.h"

#include <zephyr/bluetooth/buf.h>
#include <zephyr/bluetooth/hci_raw.h>

#include "bluetooth.h"
#include "btstack_debug.h"

static K_FIFO_DEFINE(rx_queue);
static void (*packet_handler)(uint8_t packet_type, uint8_t *packet, uint16_t size);

static void transport_init(const void *config) {
    (void)config;
    bt_enable_raw(&rx_queue);
    bt_hci_raw_set_mode(BT_HCI_RAW_MODE_PASSTHROUGH);
}

static int transport_open(void) {
    return 0;
}

static int transport_close(void) {
    return 0;
}

static void transport_register_packet_handler(void (*handler)(uint8_t packet_type, uint8_t *packet, uint16_t size)) {
    packet_handler = handler;
}

static enum bt_buf_type outgoing_buffer_type(uint8_t packet_type) {
    switch (packet_type) {
    case HCI_COMMAND_DATA_PACKET:
        return BT_BUF_CMD;
    case HCI_ACL_DATA_PACKET:
        return BT_BUF_ACL_OUT;
    default:
        return BT_BUF_ISO_OUT;
    }
}

static int transport_send_packet(uint8_t packet_type, uint8_t *packet, int size) {
    struct net_buf *buffer = bt_buf_get_tx(outgoing_buffer_type(packet_type), K_NO_WAIT, packet, size);
    if (buffer == NULL) {
        log_error("no HCI buffer for packet type %u", packet_type);
        return 0;
    }
    bt_send(buffer);
    return 0;
}

static const hci_transport_t transport = {
    "zephyr",
    &transport_init,
    &transport_open,
    &transport_close,
    &transport_register_packet_handler,
    NULL,
    &transport_send_packet,
    NULL,
    NULL,
    NULL,
};

const hci_transport_t *zephyr_hci_transport_instance(void) {
    return &transport;
}

struct k_fifo *zephyr_hci_transport_rx_queue(void) {
    return &rx_queue;
}

void zephyr_hci_transport_deliver(struct net_buf *buffer) {
    switch (bt_buf_get_type(buffer)) {
    case BT_BUF_ACL_IN:
        packet_handler(HCI_ACL_DATA_PACKET, buffer->data, buffer->len);
        break;
    case BT_BUF_EVT:
        packet_handler(HCI_EVENT_PACKET, buffer->data, buffer->len);
        break;
    default:
        log_error("unexpected HCI buffer type %u", bt_buf_get_type(buffer));
        break;
    }
    net_buf_unref(buffer);
}
