#ifndef TEST_REPLAY_H
#define TEST_REPLAY_H

#include "test_framework.h"
#include "test_support.h"

#include "protocol/command_frame.h"
#include "protocol/command_set.h"

#define REPLAY_PREFIX_SIZE 17
#define REPLAY_MAX_LINE 4096
#define REPLAY_MAX_FRAME 600

static bool replay_exchange(const command_set_t *set, const char *request_hex, const char *reply_hex) {
    uint8_t request_value[REPLAY_MAX_FRAME];
    uint8_t expected_reply[REPLAY_MAX_FRAME];
    uint8_t payload[REPLAY_MAX_FRAME];
    uint8_t actual_reply[REPLAY_MAX_FRAME];
    command_request_t request;
    size_t payload_length = 0;

    size_t request_size = hex_decode(request_hex, request_value, sizeof(request_value));
    size_t expected_size = hex_decode(reply_hex, expected_reply, sizeof(expected_reply));

    ASSERT_EQ(command_frame_parse_request(request_value, request_size, REPLAY_PREFIX_SIZE, &request), COMMAND_FRAME_OK);
    ASSERT_EQ(command_router_dispatch(&set->router, &request, payload, sizeof(payload), &payload_length), COMMAND_ROUTER_HANDLED);

    size_t actual_size = command_frame_build_reply(&request, payload, payload_length, actual_reply, sizeof(actual_reply));
    ASSERT_EQ(actual_size, expected_size);
    ASSERT_MEM_EQ(actual_reply, expected_reply, expected_size);
    return true;
}

static bool replay_fixture(const command_set_t *set, const char *path, int *replayed) {
    FILE *fixture = fopen(path, "r");
    ASSERT(fixture != NULL);
    char line[REPLAY_MAX_LINE];
    char request_hex[REPLAY_MAX_LINE];
    char reply_hex[REPLAY_MAX_LINE];
    *replayed = 0;

    while (fgets(line, sizeof(line), fixture) != NULL) {
        ASSERT_EQ(sscanf(line, "%s %s", request_hex, reply_hex), 2);
        if (!replay_exchange(set, request_hex, reply_hex)) {
            printf("    exchange %d: %.40s...\n", *replayed + 1, request_hex);
            fclose(fixture);
            return false;
        }
        (*replayed)++;
    }
    fclose(fixture);
    return true;
}

#endif
