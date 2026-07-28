#include "c_test_runtime.h"

int c_test_heap_next(uintptr_t heap_start, uintptr_t heap_current,
                     ptrdiff_t increment, uintptr_t heap_limit,
                     uintptr_t *heap_next)
{
    uintptr_t next;

    if (heap_current < heap_start || heap_current > heap_limit) return 0;

    if (increment >= 0) {
        uintptr_t amount = (uintptr_t)increment;
        if (amount > heap_limit - heap_current) return 0;
        next = heap_current + amount;
    } else {
        uintptr_t amount = (uintptr_t)(-(increment + 1)) + 1;
        if (amount > heap_current - heap_start) return 0;
        next = heap_current - amount;
    }

    *heap_next = next;
    return 1;
}

#ifndef C_TEST_HOST

extern char _heap_start;
extern char _stack_top;
static uintptr_t heap_current;

void *_sbrk(ptrdiff_t increment)
{
    uintptr_t heap_start = (uintptr_t)&_heap_start;
    uintptr_t stack_limit = (uintptr_t)&_stack_top;
    uintptr_t stack_pointer;
    uintptr_t heap_next;

    if (heap_current == 0) heap_current = heap_start;
    __asm__ volatile ("mv %0, sp" : "=r"(stack_pointer));
    if (stack_pointer < stack_limit) stack_limit = stack_pointer;

    if (!c_test_heap_next(heap_start, heap_current, increment, stack_limit,
                          &heap_next)) {
        return (void *)-1;
    }

    void *previous = (void *)heap_current;
    heap_current = heap_next;
    return previous;
}

void *malloc(size_t size)
{
    size_t aligned = (size + 7u) & ~(size_t)7u;
    if (aligned < size || aligned > (size_t)PTRDIFF_MAX - sizeof(size_t)) {
        return NULL;
    }

    size_t total = aligned + sizeof(size_t);
    size_t *header = (size_t *)_sbrk((ptrdiff_t)total);
    if (header == (void *)-1) return NULL;
    *header = total;
    return header + 1;
}

void free(void *pointer)
{
    if (pointer == NULL) return;

    size_t *header = (size_t *)pointer - 1;
#ifndef C_TEST_HOST
    if ((uintptr_t)header + *header == heap_current) {
        (void)_sbrk(-(ptrdiff_t)*header);
    }
#else
    (void)header;
#endif
}

void *memset(void *destination, int value, size_t size)
{
    unsigned char *output = destination;
    while (size-- != 0) *output++ = (unsigned char)value;
    return destination;
}

size_t strnlen(const char *string, size_t limit)
{
    size_t length = 0;
    while (length < limit && string[length] != '\0') length++;
    return length;
}

#endif
