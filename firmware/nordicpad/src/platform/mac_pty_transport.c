#include "platform/mac_pty_transport.h"

#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#include "platform/log.h"

#define READ_BUFFER_SIZE 512

static int configure_slave(mac_pty_transport_t *transport) {
    transport->slave_fd = open(transport->slave_path, O_RDWR | O_NOCTTY);
    if (transport->slave_fd < 0) {
        return -1;
    }

    struct termios settings;
    if (tcgetattr(transport->slave_fd, &settings) != 0) {
        return -1;
    }
    cfmakeraw(&settings);
    settings.c_cflag &= ~(tcflag_t)HUPCL;
    settings.c_cflag |= CLOCAL;
    return tcsetattr(transport->slave_fd, TCSANOW, &settings);
}

static void publish_link(mac_pty_transport_t *transport, const char *link_path) {
    snprintf(transport->link_path, sizeof(transport->link_path), "%s", link_path);
    unlink(link_path);
    if (symlink(transport->slave_path, link_path) != 0) {
        LOG("could not link %s to %s", link_path, transport->slave_path);
    }
}

static void on_readable(btstack_data_source_t *source, btstack_data_source_callback_type_t type) {
    if (type != DATA_SOURCE_CALLBACK_READ) {
        return;
    }

    mac_pty_transport_t *transport = (mac_pty_transport_t *)((char *)source - offsetof(mac_pty_transport_t, data_source));
    uint8_t buffer[READ_BUFFER_SIZE];
    ssize_t count = read(transport->master_fd, buffer, sizeof(buffer));
    if (count > 0 && transport->on_receive != NULL) {
        transport->on_receive(transport->receive_context, buffer, (size_t)count);
    }
}

static void start(void *context, host_receive_fn on_receive, void *receive_context) {
    mac_pty_transport_t *transport = context;
    transport->on_receive = on_receive;
    transport->receive_context = receive_context;

    btstack_run_loop_set_data_source_fd(&transport->data_source, transport->master_fd);
    btstack_run_loop_set_data_source_handler(&transport->data_source, on_readable);
    btstack_run_loop_enable_data_source_callbacks(&transport->data_source, DATA_SOURCE_CALLBACK_READ);
    btstack_run_loop_add_data_source(&transport->data_source);
}

static void write_bytes(void *context, const uint8_t *data, size_t length) {
    mac_pty_transport_t *transport = context;
    size_t written = 0;
    while (written < length) {
        ssize_t count = write(transport->master_fd, &data[written], length - written);
        if (count <= 0) {
            if (count < 0 && errno == EINTR) {
                continue;
            }
            LOG("host channel write failed after %zu of %zu bytes: %s", written, length, strerror(errno));
            return;
        }
        written += (size_t)count;
    }
}

int mac_pty_transport_open(mac_pty_transport_t *transport, const char *link_path) {
    memset(transport, 0, sizeof(*transport));
    transport->slave_fd = -1;

    transport->master_fd = posix_openpt(O_RDWR | O_NOCTTY);
    if (transport->master_fd < 0 || grantpt(transport->master_fd) != 0 || unlockpt(transport->master_fd) != 0) {
        return -1;
    }

    const char *slave_path = ptsname(transport->master_fd);
    if (slave_path == NULL) {
        return -1;
    }
    snprintf(transport->slave_path, sizeof(transport->slave_path), "%s", slave_path);

    if (configure_slave(transport) != 0) {
        return -1;
    }
    fcntl(transport->master_fd, F_SETFL, fcntl(transport->master_fd, F_GETFL) | O_NONBLOCK);

    publish_link(transport, link_path);
    LOG("host channel: %s (%s)", transport->link_path, transport->slave_path);
    return 0;
}

host_transport_t mac_pty_transport_interface(mac_pty_transport_t *transport) {
    return (host_transport_t){start, write_bytes, transport};
}
