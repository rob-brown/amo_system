#ifndef PROTOCOL_REPLY_QUEUE_H
#define PROTOCOL_REPLY_QUEUE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define REPLY_QUEUE_SLOTS 8
#define REPLY_QUEUE_SLOT_SIZE 512

typedef struct {
    uint8_t frames[REPLY_QUEUE_SLOTS][REPLY_QUEUE_SLOT_SIZE];
    size_t lengths[REPLY_QUEUE_SLOTS];
    size_t head;
    size_t count;
} reply_queue_t;

void reply_queue_init(reply_queue_t *queue);

bool reply_queue_push(reply_queue_t *queue, const uint8_t *frame, size_t length);

const uint8_t *reply_queue_peek(const reply_queue_t *queue, size_t *length);

void reply_queue_pop(reply_queue_t *queue);

bool reply_queue_is_empty(const reply_queue_t *queue);

#endif
