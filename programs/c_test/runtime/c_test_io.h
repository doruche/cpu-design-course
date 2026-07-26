#ifndef C_TEST_IO_H
#define C_TEST_IO_H

#include <stdint.h>

typedef unsigned long long time_l;

#ifndef C_TEST_CPU_CLOCK_HZ
#define C_TEST_CPU_CLOCK_HZ 50000000ull
#endif

#define CLKS_PER_SEC C_TEST_CPU_CLOCK_HZ
#define C_TEST_MAX_ARRAY_ITEMS 4096

void uart_init(void);
void uart_putc(char character);
time_l get_time(void);
void delay_ms(int milliseconds);
void c_test_print_time_ms(time_l clock_ticks);

int c_test_printf(const char *format, ...);
int c_test_scanf(const char *format, ...);

#define printf c_test_printf
#define scanf c_test_scanf

#endif
