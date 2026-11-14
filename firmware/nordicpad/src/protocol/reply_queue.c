#include "protocol/reply_queue.h"

#include <string.h>

void reply_queue_init(reply_queue_t *queue) {
    queue->head = 0;
    queue->count = 0;
}

bool reply_queue_push(reply_queue_t *queue, const uint8_t *frame, size_t length) {
    if (queue->count == REPLY_QUEUE_SLOTS || length > REPLY_QUEUE_SLOT_SIZE) {
        return false;
    }

    size_t slot = (queue->head + queue->count) % REPLY_QUEUE_SLOTS;
    memcpy(queue->frames[slot], frame, length);
    queue->lengths[slot] = length;
    queue->count++;
    return true;
}

const uint8_t *reply_queue_peek(const reply_queue_t *queue, size_t *length) {
    if (queue->count == 0) {
        return NULL;
    }

    *length = queue->lengths[queue->head];
    return queue->frames[queue->head];
}

void reply_queue_pop(reply_queue_t *queue) {
    if (queue->count == 0) {
        return;
    }

    queue->head = (queue->head + 1) % REPLY_QUEUE_SLOTS;
    queue->count--;
}

bool reply_queue_is_empty(const reply_queue_t *queue) {
    return queue->count == 0;
}
