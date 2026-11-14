#ifndef PLATFORM_MAC_PTY_TRANSPORT_H
#define PLATFORM_MAC_PTY_TRANSPORT_H

#include <limits.h>

#include "btstack_run_loop.h"
#include "platform/host_transport.h"

typedef struct {
    int master_fd;
    int slave_fd;
    char slave_path[PATH_MAX];
    char link_path[PATH_MAX];
    btstack_data_source_t data_source;
    host_receive_fn on_receive;
    void *receive_context;
} mac_pty_transport_t;

int mac_pty_transport_open(mac_pty_transport_t *transport, const char *link_path);

host_transport_t mac_pty_transport_interface(mac_pty_transport_t *transport);

#endif
