#ifndef LOGGING_H
#define LOGGING_H

#include "host_protocol.h"

void logging_init(host_protocol_t *proto);

void pico_log_emergency(const char *msg);
void pico_log_alert(const char *msg);
void pico_log_critical(const char *msg);
void pico_log_error(const char *msg);
void pico_log_warning(const char *msg);
void pico_log_notice(const char *msg);
void pico_log_info(const char *msg);
void pico_log_debug(const char *msg);

void pico_log_emergencyf(const char *fmt, ...);
void pico_log_alertf(const char *fmt, ...);
void pico_log_criticalf(const char *fmt, ...);
void pico_log_errorf(const char *fmt, ...);
void pico_log_warningf(const char *fmt, ...);
void pico_log_noticef(const char *fmt, ...);
void pico_log_infof(const char *fmt, ...);
void pico_log_debugf(const char *fmt, ...);

#endif
