#ifndef C_TEST_FREESTANDING_STDLIB_H
#define C_TEST_FREESTANDING_STDLIB_H

/* See freestanding/string.h. CoreMark's MEM_STATIC configuration never reaches
   the allocator, but core_portme.c still includes this header. */

#include <stddef.h>

void *malloc(size_t size);
void free(void *pointer);

#endif
