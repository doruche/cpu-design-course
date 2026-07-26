#ifndef C_TEST_RUNTIME_H
#define C_TEST_RUNTIME_H

#include <stddef.h>
#include <stdint.h>

int c_test_heap_next(uintptr_t heap_start, uintptr_t heap_current,
                     ptrdiff_t increment, uintptr_t heap_limit,
                     uintptr_t *heap_next);

void *malloc(size_t size);
void free(void *pointer);
void *memset(void *destination, int value, size_t size);

#endif
