#include "logging.h"

#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>

#define LOG_BUFFER_SIZE 256

static host_protocol_t *g_proto = NULL;

void logging_init(host_protocol_t *proto) {
    g_proto = proto;
}

void pico_log_emergency(const char *msg) {
    if (g_proto != NULL) {
        host_protocol_log(g_proto, HOST_LOG_EMERGENCY, msg);
    }
}

void pico_log_alert(const char *msg) {
    if (g_proto != NULL) {
        host_protocol_log(g_proto, HOST_LOG_ALERT, msg);
    }
}

void pico_log_critical(const char *msg) {
    if (g_proto != NULL) {
        host_protocol_log(g_proto, HOST_LOG_CRITICAL, msg);
    }
}

void pico_log_error(const char *msg) {
    if (g_proto != NULL) {
        host_protocol_log(g_proto, HOST_LOG_ERROR, msg);
    }
}

void pico_log_warning(const char *msg) {
    if (g_proto != NULL) {
        host_protocol_log(g_proto, HOST_LOG_WARNING, msg);
    }
}

void pico_log_notice(const char *msg) {
    if (g_proto != NULL) {
        host_protocol_log(g_proto, HOST_LOG_NOTICE, msg);
    }
}

void pico_log_info(const char *msg) {
    if (g_proto != NULL) {
        host_protocol_log(g_proto, HOST_LOG_INFO, msg);
    }
}

void pico_log_debug(const char *msg) {
    if (g_proto != NULL) {
        host_protocol_log(g_proto, HOST_LOG_DEBUG, msg);
    }
}

void pico_log_emergencyf(const char *fmt, ...) {
    if (g_proto != NULL) {
        static char buffer[LOG_BUFFER_SIZE];
        va_list args;
        va_start(args, fmt);
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        va_end(args);
        host_protocol_log(g_proto, HOST_LOG_EMERGENCY, buffer);
    }
}

void pico_log_alertf(const char *fmt, ...) {
    if (g_proto != NULL) {
        static char buffer[LOG_BUFFER_SIZE];
        va_list args;
        va_start(args, fmt);
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        va_end(args);
        host_protocol_log(g_proto, HOST_LOG_ALERT, buffer);
    }
}

void pico_log_criticalf(const char *fmt, ...) {
    if (g_proto != NULL) {
        static char buffer[LOG_BUFFER_SIZE];
        va_list args;
        va_start(args, fmt);
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        va_end(args);
        host_protocol_log(g_proto, HOST_LOG_CRITICAL, buffer);
    }
}

void pico_log_errorf(const char *fmt, ...) {
    if (g_proto != NULL) {
        static char buffer[LOG_BUFFER_SIZE];
        va_list args;
        va_start(args, fmt);
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        va_end(args);
        host_protocol_log(g_proto, HOST_LOG_ERROR, buffer);
    }
}

void pico_log_warningf(const char *fmt, ...) {
    if (g_proto != NULL) {
        static char buffer[LOG_BUFFER_SIZE];
        va_list args;
        va_start(args, fmt);
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        va_end(args);
        host_protocol_log(g_proto, HOST_LOG_WARNING, buffer);
    }
}

void pico_log_noticef(const char *fmt, ...) {
    if (g_proto != NULL) {
        static char buffer[LOG_BUFFER_SIZE];
        va_list args;
        va_start(args, fmt);
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        va_end(args);
        host_protocol_log(g_proto, HOST_LOG_NOTICE, buffer);
    }
}

void pico_log_infof(const char *fmt, ...) {
    if (g_proto != NULL) {
        static char buffer[LOG_BUFFER_SIZE];
        va_list args;
        va_start(args, fmt);
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        va_end(args);
        host_protocol_log(g_proto, HOST_LOG_INFO, buffer);
    }
}

void pico_log_debugf(const char *fmt, ...) {
    if (g_proto != NULL) {
        static char buffer[LOG_BUFFER_SIZE];
        va_list args;
        va_start(args, fmt);
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        va_end(args);
        host_protocol_log(g_proto, HOST_LOG_DEBUG, buffer);
    }
}
