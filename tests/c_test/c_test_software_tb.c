#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "c_test_runtime.h"

#define UART_BASE 0xFFFF3000u
#define TIMER_BASE 0xFFFF4000u

static unsigned int status_full_reads;
static unsigned int status_reads;
static unsigned char rx_data[256];
static size_t rx_size;
static size_t rx_position;
static char tx_data[4096];
static size_t tx_size;
static unsigned int control_value;
static unsigned int timer_high_data[8];
static size_t timer_high_size;
static size_t timer_high_position;
static unsigned int timer_low_data[8];
static size_t timer_low_size;
static size_t timer_low_position;

static void fail(const char *message)
{
    fprintf(stderr, "c_test_software_tb: FAIL: %s\n", message);
    exit(1);
}

static void check(int condition, const char *message)
{
    if (!condition) fail(message);
}

static void reset_mmio(void)
{
    status_full_reads = 0;
    status_reads = 0;
    rx_size = 0;
    rx_position = 0;
    tx_size = 0;
    control_value = 0;
    timer_high_size = 0;
    timer_high_position = 0;
    timer_low_size = 0;
    timer_low_position = 0;
}

#if defined(TEST_UART_FORMAT)
static void provide_rx(const char *text)
{
    rx_size = strlen(text);
    check(rx_size <= sizeof(rx_data), "RX fixture exceeds host queue");
    memcpy(rx_data, text, rx_size);
    rx_position = 0;
}
#endif

unsigned int c_test_mmio_read(unsigned int address)
{
    if (address == UART_BASE + 8) {
        unsigned int status = rx_position < rx_size ? 1u : 0u;
        if (status_full_reads != 0) {
            status |= 8u;
            status_full_reads--;
        }
        status_reads++;
        return status;
    }
    if (address == UART_BASE) {
        if (rx_position >= rx_size) fail("RX FIFO read while empty");
        return rx_data[rx_position++];
    }
    if (address == TIMER_BASE) {
        if (timer_low_position >= timer_low_size) fail("timer low fixture empty");
        return timer_low_data[timer_low_position++];
    }
    if (address == TIMER_BASE + 8) {
        if (timer_high_position >= timer_high_size) fail("timer high fixture empty");
        return timer_high_data[timer_high_position++];
    }
    fail("unexpected MMIO read");
    return 0;
}

void c_test_mmio_write(unsigned int address, unsigned int value)
{
    if (address == UART_BASE + 12) {
        control_value = value;
        return;
    }
    if (address == UART_BASE + 4) {
        if (tx_size == sizeof(tx_data)) fail("TX capture overflow");
        tx_data[tx_size++] = (char)value;
        return;
    }
    fail("unexpected MMIO write");
}

#if defined(TEST_UART_FORMAT)

#include "peripheral.h"

static void test_uart_helpers(void)
{
    reset_mmio();
    uart_init();
    check(control_value == 3, "uart_init did not clear both FIFOs");

    status_full_reads = 2;
    uart_putc('A');
    check(status_reads == 3, "uart_putc did not wait for TX space");
    check(tx_size == 1 && tx_data[0] == 'A', "uart_putc wrote wrong byte");
}

static void test_format_and_scan(void)
{
    int value = 0;
    char character = 0;
    char text[32] = {0};

    reset_mmio();
    uart_init();
    c_test_printf("%d 0x%x %c %s %f\n", -123, 0x456u, 'c', "hello", 98.7654);
    tx_data[tx_size] = '\0';
    check(strcmp(tx_data, "-123 0x456 c hello 98.765400\n\r") == 0,
          "formatted output contract changed");

    reset_mmio();
    uart_init();
    provide_rx("-42 x hello\n");
    check(c_test_scanf("%d %c %s", &value, &character, text) == 3,
          "formatted input conversion count mismatch");
    check(value == -42 && character == 'x' && strcmp(text, "hello") == 0,
          "formatted input values mismatch");
}

int main(void)
{
    test_uart_helpers();
    test_format_and_scan();
    puts("c_test_software_tb (uart-format): PASS");
    return 0;
}

#elif defined(TEST_TIMER_SORT_HEAP)

#include "peripheral.h"

void quick_sort(int array[], int low, int high);

static void test_timer_rollover(void)
{
    reset_mmio();
    timer_high_data[0] = 1;
    timer_high_data[1] = 2;
    timer_high_data[2] = 2;
    timer_high_data[3] = 2;
    timer_high_size = 4;
    timer_low_data[0] = 0xFFFFFFF0u;
    timer_low_data[1] = 0x00000020u;
    timer_low_size = 2;
    check(get_time() == 0x0000000200000020ull,
          "timer high-low-high retry did not return one coherent value");
}

static void test_sort(void)
{
    int array[] = {8, -1, 5, 3, 0, 5, 2, 1};
    size_t count = sizeof(array) / sizeof(array[0]);
    quick_sort(array, 0, (int)count - 1);
    for (size_t index = 1; index < count; index++) {
        check(array[index - 1] <= array[index], "quicksort result is descending");
    }
}

static void test_heap_bounds(void)
{
    uintptr_t next = 0;
    check(c_test_heap_next(0x1000, 0x1000, 16, 0x2000, &next) &&
          next == 0x1010, "heap growth inside bounds failed");
    check(!c_test_heap_next(0x1000, 0x1ff0, 17, 0x2000, &next),
          "heap growth crossed the stack limit");
    check(c_test_heap_next(0x1000, 0x1010, -16, 0x2000, &next) &&
          next == 0x1000, "heap shrink inside bounds failed");
    check(!c_test_heap_next(0x1000, 0x1000, -1, 0x2000, &next),
          "heap shrink crossed the heap origin");
    check(!c_test_heap_next(0x1000, 0x2001, 1, 0x2000, &next),
          "heap accepted a current pointer beyond its limit");
}

int main(void)
{
    test_timer_rollover();
    test_sort();
    test_heap_bounds();
    puts("c_test_software_tb (timer-sort-heap): PASS");
    return 0;
}

#else
#error Select one C_TEST host suite
#endif
