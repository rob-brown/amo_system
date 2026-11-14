#ifndef TEST_FRAMEWORK_H
#define TEST_FRAMEWORK_H

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static int g_passed = 0;
static int g_failed = 0;
static int g_total = 0;

#define RUN_TEST(fn) do { \
    g_total++; \
    printf("  [TEST] %s... ", #fn); \
    fflush(stdout); \
    if (fn()) { \
        g_passed++; \
        printf("PASS\n"); \
    } else { \
        g_failed++; \
        printf("FAIL\n"); \
    } \
} while(0)

#define TEST_MAIN_BEGIN(suite_name) \
    int main(void) { \
        printf("=== Test Suite: %s ===\n\n", suite_name);

#define TEST_MAIN_END() \
        printf("\n=== Results: %d/%d passed", g_passed, g_total); \
        if (g_failed > 0) { \
            printf(" (%d FAILED)", g_failed); \
        } \
        printf(" ===\n"); \
        return g_failed > 0 ? 1 : 0; \
    }

#define ASSERT(cond) \
    do { \
        if (!(cond)) { \
            printf("\n    ASSERT FAILED: %s (line %d)\n    ", #cond, __LINE__); \
            return false; \
        } \
    } while(0)

#define ASSERT_EQ(a, b) \
    do { \
        if ((a) != (b)) { \
            printf("\n    ASSERT_EQ FAILED: %s == %s (line %d)\n    ", #a, #b, __LINE__); \
            return false; \
        } \
    } while(0)

#define ASSERT_MEM_EQ(a, b, len) \
    do { \
        if (memcmp((a), (b), (len)) != 0) { \
            printf("\n    ASSERT_MEM_EQ FAILED: %s == %s (len=%zu, line %d)\n    ", #a, #b, (size_t)(len), __LINE__); \
            return false; \
        } \
    } while(0)

static inline void print_hex(const char *label, const uint8_t *data, size_t len) {
    printf("    %s: ", label);
    for (size_t i = 0; i < len; i++) {
        printf("%02X ", data[i]);
    }
    printf("\n");
}

#endif
