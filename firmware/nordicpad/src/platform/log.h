#ifndef PLATFORM_LOG_H
#define PLATFORM_LOG_H

#include <stdio.h>

#include "btstack_run_loop.h"

#define LOG(...)                                                        \
    do {                                                                \
        printf("[%8u] ", (unsigned)btstack_run_loop_get_time_ms());     \
        printf(__VA_ARGS__);                                            \
        printf("\n");                                                   \
    } while (0)

#endif
