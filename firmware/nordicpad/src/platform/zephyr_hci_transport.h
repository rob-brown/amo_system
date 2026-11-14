#ifndef PLATFORM_ZEPHYR_HCI_TRANSPORT_H
#define PLATFORM_ZEPHYR_HCI_TRANSPORT_H

#include <zephyr/kernel.h>
#include <zephyr/net_buf.h>

#include "hci_transport.h"

const hci_transport_t *zephyr_hci_transport_instance(void);
struct k_fifo *zephyr_hci_transport_rx_queue(void);
void zephyr_hci_transport_deliver(struct net_buf *buffer);

#endif
