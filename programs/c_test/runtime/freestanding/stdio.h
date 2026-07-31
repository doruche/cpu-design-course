#ifndef C_TEST_FREESTANDING_STDIO_H
#define C_TEST_FREESTANDING_STDIO_H

/* See freestanding/string.h. CoreMark routes all output through ee_printf,
   which core_portme.h binds to sc_printf, so nothing from hosted stdio is
   used; core_portme.c just includes the header unconditionally. */

#endif
