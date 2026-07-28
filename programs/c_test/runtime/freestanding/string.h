#ifndef C_TEST_FREESTANDING_STRING_H
#define C_TEST_FREESTANDING_STRING_H

/* The RISC-V toolchain ships no rv32im/ilp32 libc, so the imported CoreMark
   port's hosted includes resolve here instead. Only the declarations that port
   actually uses are provided. */

#include <stddef.h>

void *memset(void *destination, int value, size_t size);
size_t strnlen(const char *string, size_t limit);

#endif
