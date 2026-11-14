#include "test_framework.h"

#include "protocol/reply_queue.h"

static bool test_frames_come_out_in_the_order_they_went_in(void) {
    // Arrange
    reply_queue_t queue;
    reply_queue_init(&queue);
    const uint8_t first[] = {0x01, 0x02};
    const uint8_t second[] = {0x03};
    size_t length = 0;

    // Act
    reply_queue_push(&queue, first, sizeof(first));
    reply_queue_push(&queue, second, sizeof(second));
    const uint8_t *head = reply_queue_peek(&queue, &length);

    // Assert
    ASSERT_EQ(length, sizeof(first));
    ASSERT_MEM_EQ(head, first, length);
    reply_queue_pop(&queue);
    head = reply_queue_peek(&queue, &length);
    ASSERT_EQ(length, sizeof(second));
    ASSERT_MEM_EQ(head, second, length);
    return true;
}

static bool test_empty_queue_has_nothing_to_peek(void) {
    // Arrange
    reply_queue_t queue;
    reply_queue_init(&queue);
    size_t length = 99;

    // Act
    const uint8_t *head = reply_queue_peek(&queue, &length);

    // Assert
    ASSERT(head == NULL);
    ASSERT(reply_queue_is_empty(&queue));
    return true;
}

static bool test_full_queue_refuses_another_frame(void) {
    // Arrange
    reply_queue_t queue;
    reply_queue_init(&queue);
    const uint8_t frame[] = {0xAA};
    for (size_t index = 0; index < REPLY_QUEUE_SLOTS; index++) {
        ASSERT(reply_queue_push(&queue, frame, sizeof(frame)));
    }

    // Act
    bool accepted = reply_queue_push(&queue, frame, sizeof(frame));

    // Assert
    ASSERT(!accepted);
    return true;
}

static bool test_oversized_frame_is_refused(void) {
    // Arrange
    reply_queue_t queue;
    reply_queue_init(&queue);
    static uint8_t frame[REPLY_QUEUE_SLOT_SIZE + 1];

    // Act
    bool accepted = reply_queue_push(&queue, frame, sizeof(frame));

    // Assert
    ASSERT(!accepted);
    return true;
}

static bool test_slots_are_reused_after_popping(void) {
    // Arrange
    reply_queue_t queue;
    reply_queue_init(&queue);
    uint8_t frame[1];
    size_t length = 0;
    for (size_t round = 0; round < REPLY_QUEUE_SLOTS * 3; round++) {
        frame[0] = (uint8_t)round;

        // Act
        ASSERT(reply_queue_push(&queue, frame, sizeof(frame)));
        const uint8_t *head = reply_queue_peek(&queue, &length);

        // Assert
        ASSERT_EQ(head[0], (uint8_t)round);
        reply_queue_pop(&queue);
    }
    return true;
}

TEST_MAIN_BEGIN("reply_queue")
    RUN_TEST(test_frames_come_out_in_the_order_they_went_in);
    RUN_TEST(test_empty_queue_has_nothing_to_peek);
    RUN_TEST(test_full_queue_refuses_another_frame);
    RUN_TEST(test_oversized_frame_is_refused);
    RUN_TEST(test_slots_are_reused_after_popping);
TEST_MAIN_END()
