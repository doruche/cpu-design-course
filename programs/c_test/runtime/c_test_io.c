#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>

#include "c_test_io.h"

#define UART_BASE 0xFFFF3000u
#define TIMER_BASE 0xFFFF4000u

#define UART_RX_FIFO (UART_BASE + 0x0u)
#define UART_TX_FIFO (UART_BASE + 0x4u)
#define UART_STATUS  (UART_BASE + 0x8u)
#define UART_CONTROL (UART_BASE + 0xCu)
#define TIMER_LOW    (TIMER_BASE + 0x0u)
#define TIMER_HIGH   (TIMER_BASE + 0x8u)

#define UART_STATUS_TX_FULL     (1u << 3)
#define UART_STATUS_RX_NOT_EMPTY (1u << 0)
#define UART_CONTROL_CLEAR_FIFOS ((1u << 1) | (1u << 0))

#define RX_FIFO_SIZE 512
#define SCAN_BUF_SIZE 128

#ifdef C_TEST_HOST
extern unsigned int c_test_mmio_read(unsigned int address);
extern void c_test_mmio_write(unsigned int address, unsigned int value);
#else
static unsigned int c_test_mmio_read(unsigned int address)
{
    return *(volatile unsigned int *)(uintptr_t)address;
}

static void c_test_mmio_write(unsigned int address, unsigned int value)
{
    *(volatile unsigned int *)(uintptr_t)address = value;
}
#endif

static char rx_buffer[RX_FIFO_SIZE];
static int rx_count;
static int rx_position;

void uart_init(void)
{
    c_test_mmio_write(UART_CONTROL, UART_CONTROL_CLEAR_FIFOS);
    rx_count = 0;
    rx_position = 0;
}

void uart_putc(char character)
{
    while (c_test_mmio_read(UART_STATUS) & UART_STATUS_TX_FULL) {
    }
    c_test_mmio_write(UART_TX_FIFO, (unsigned char)character);
}

static char uart_getc(void)
{
    if (rx_position >= rx_count) {
        rx_position = 0;
        rx_count = 0;

        while (!(c_test_mmio_read(UART_STATUS) & UART_STATUS_RX_NOT_EMPTY)) {
        }
        while ((c_test_mmio_read(UART_STATUS) & UART_STATUS_RX_NOT_EMPTY) &&
               rx_count < RX_FIFO_SIZE) {
            rx_buffer[rx_count++] = (char)c_test_mmio_read(UART_RX_FIFO);
        }
    }

    return rx_buffer[rx_position++];
}

time_l get_time(void)
{
    unsigned int high_before;
    unsigned int low;
    unsigned int high_after;

    do {
        high_before = c_test_mmio_read(TIMER_HIGH);
        low = c_test_mmio_read(TIMER_LOW);
        high_after = c_test_mmio_read(TIMER_HIGH);
    } while (high_before != high_after);

    return ((time_l)high_after << 32) | low;
}

void delay_ms(int milliseconds)
{
    if (milliseconds <= 0) return;

    time_l start = get_time();
    time_l duration = (time_l)milliseconds * CLKS_PER_SEC / 1000u;
    while (get_time() - start < duration) {
    }
}

static void print_char(char character)
{
    uart_putc(character);
    if (character == '\n') uart_putc('\r');
}

static void print_string(const char *string)
{
    while (*string) print_char(*string++);
}

static void print_number(unsigned int number, unsigned int base, int is_signed)
{
    char buffer[32];
    char *position = buffer;
    static const char digits[] = "0123456789ABCDEF";

    if (is_signed && (int)number < 0) {
        print_char('-');
        number = 0u - number;
    }

    do {
        *position++ = digits[number % base];
        number /= base;
    } while (number > 0);

    while (position > buffer) print_char(*--position);
}

struct two_words {
    uint32_t high;
    uint32_t low;
};

static struct two_words multiply_by_ten(struct two_words value)
{
    uint32_t lower_half = (value.low & 0xFFFFu) * 10u;
    uint32_t upper_half = (value.low >> 16) * 10u + (lower_half >> 16);
    struct two_words result;
    result.low = (upper_half << 16) | (lower_half & 0xFFFFu);
    result.high = value.high * 10u + (upper_half >> 16);
    return result;
}

static uint32_t shifted_word(struct two_words value, unsigned int shift)
{
    if (shift == 0) return value.low;
    if (shift < 32) {
        return (value.high << (32 - shift)) | (value.low >> shift);
    }
    if (shift < 64) return value.high >> (shift - 32);
    return 0;
}

static struct two_words lower_bits(struct two_words value, unsigned int count)
{
    if (count == 0) {
        value.high = 0;
        value.low = 0;
    } else if (count < 32) {
        value.high = 0;
        value.low &= (1u << count) - 1u;
    } else if (count == 32) {
        value.high = 0;
    } else if (count < 64) {
        value.high &= (1u << (count - 32)) - 1u;
    }
    return value;
}

static void print_float(double number, int precision)
{
    union {
        double number;
        struct {
            uint32_t low;
            uint32_t high;
        } words;
    } bits;
    bits.number = number;

    int sign = (int)(bits.words.high >> 31);
    unsigned int exponent_bits = (bits.words.high >> 20) & 0x7FFu;
    if (exponent_bits == 0x7FFu) {
        print_string((bits.words.high & 0xFFFFFu) || bits.words.low
                         ? "nan" : (sign ? "-inf" : "inf"));
        return;
    }
    if (sign) print_char('-');
    if (precision < 0 || precision > 6) precision = 6;
    if (exponent_bits == 0) {
        print_number(0, 10, 0);
        if (precision != 0) {
            print_char('.');
            for (int index = 0; index < precision; index++) print_char('0');
        }
        return;
    }

    int exponent = (int)exponent_bits - 1023;
    if (exponent > 31) {
        print_string("overflow");
        return;
    }

    struct two_words mantissa = {
        .high = (bits.words.high & 0xFFFFFu) | 0x100000u,
        .low = bits.words.low,
    };
    unsigned int fractional_bits = (unsigned int)(52 - exponent);
    if (fractional_bits >= 64) {
        print_number(0, 10, 0);
        if (precision != 0) {
            print_char('.');
            for (int index = 0; index < precision; index++) print_char('0');
        }
        return;
    }

    unsigned int integer_part = shifted_word(mantissa, fractional_bits);
    struct two_words remainder = lower_bits(mantissa, fractional_bits);
    unsigned char digits[7] = {0};
    for (int index = 0; index <= precision; index++) {
        remainder = multiply_by_ten(remainder);
        digits[index] = (unsigned char)shifted_word(remainder, fractional_bits);
        remainder = lower_bits(remainder, fractional_bits);
    }

    if (precision < 7 && digits[precision] >= 5) {
        int index = precision - 1;
        while (index >= 0 && digits[index] == 9) digits[index--] = 0;
        if (index >= 0) {
            digits[index]++;
        } else {
            integer_part++;
        }
    }

    print_number(integer_part, 10, 0);
    if (precision > 0) {
        print_char('.');
        for (int index = 0; index < precision; index++) {
            print_char((char)('0' + digits[index]));
        }
    }
}

void c_test_print_time_ms(time_l clock_ticks)
{
    const unsigned int clocks_per_millisecond =
        (unsigned int)(CLKS_PER_SEC / 1000u);
    unsigned int milliseconds = 0;

    while (clock_ticks >= clocks_per_millisecond) {
        clock_ticks -= clocks_per_millisecond;
        milliseconds++;
    }
    unsigned int remainder = (unsigned int)clock_ticks;
    print_number(milliseconds, 10, 0);
    print_char('.');
    for (int index = 0; index < 6; index++) {
        remainder *= 10u;
        unsigned int digit = remainder / clocks_per_millisecond;
        print_char((char)('0' + digit));
        remainder -= digit * clocks_per_millisecond;
    }
}

static int c_test_vprintf(const char *format, va_list arguments)
{
    const char *position = format;
    char character;

    while ((character = *position++) != '\0') {
        if (character != '%') {
            print_char(character);
            continue;
        }

        character = *position++;
        switch (character) {
            case 'c':
                print_char((char)va_arg(arguments, int));
                break;
            case 's':
                print_string(va_arg(arguments, const char *));
                break;
            case 'd':
                print_number((unsigned int)va_arg(arguments, int), 10, 1);
                break;
            case 'u':
                print_number(va_arg(arguments, unsigned int), 10, 0);
                break;
            case 'x':
                print_number(va_arg(arguments, unsigned int), 16, 0);
                break;
            case 'f':
                print_float(va_arg(arguments, double), 6);
                break;
            case '%':
                print_char('%');
                break;
            default:
                print_char('%');
                print_char(character);
                break;
        }
    }

    return 0;
}

int c_test_printf(const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = c_test_vprintf(format, arguments);
    va_end(arguments);
    return result;
}

static void read_line(char *buffer, int maximum_length)
{
    char *position = buffer;

    while (1) {
        char character = uart_getc();
        if (character == '\r' || character == '\n') {
            print_char('\n');
            *position = '\0';
            return;
        }
        if ((character == '\b' || character == 127) && position > buffer) {
            position--;
            print_char('\b');
            print_char(' ');
            print_char('\b');
        } else if (position - buffer < maximum_length - 1) {
            print_char(character);
            *position++ = character;
        }
    }
}

static void skip_space(char **position)
{
    while (**position == ' ' || **position == '\t' || **position == '\n') {
        (*position)++;
    }
}

static int parse_integer(char **position, int *value)
{
    char *input = *position;
    unsigned int magnitude = 0;
    int negative = 0;
    int digits = 0;

    if (*input == '-' || *input == '+') {
        negative = *input == '-';
        input++;
    }
    while (*input >= '0' && *input <= '9') {
        unsigned int digit = (unsigned int)(*input - '0');
        unsigned int limit = negative ? 0x80000000u : 0x7FFFFFFFu;
        if (magnitude > (limit - digit) / 10u) return 0;
        magnitude = magnitude * 10u + digit;
        input++;
        digits++;
    }
    if (digits == 0) return 0;

    *value = negative ? (int)(0u - magnitude) : (int)magnitude;
    *position = input;
    return 1;
}

static int c_test_vscanf(const char *format, va_list arguments)
{
    static char input_buffer[SCAN_BUF_SIZE];
    static char *input_position;

    if (input_position == NULL || *input_position == '\0') {
        read_line(input_buffer, SCAN_BUF_SIZE);
        input_position = input_buffer;
    }

    const char *format_position = format;
    int converted = 0;

    while (*format_position) {
        if (*format_position == '%') {
            int width = 0;
            format_position++;
            while (*format_position >= '0' && *format_position <= '9') {
                width = width * 10 + (*format_position++ - '0');
            }
            skip_space(&input_position);
            if (*input_position == '\0') break;

            switch (*format_position) {
                case 'd': {
                    int *value = va_arg(arguments, int *);
                    if (!parse_integer(&input_position, value)) return converted;
                    converted++;
                    break;
                }
                case 'c': {
                    char *value = va_arg(arguments, char *);
                    *value = *input_position++;
                    converted++;
                    break;
                }
                case 's': {
                    char *value = va_arg(arguments, char *);
                    int copied = 0;
                    int limit = width > 0 ? width : SCAN_BUF_SIZE - 1;
                    while (*input_position && *input_position != ' ' &&
                           *input_position != '\t' && *input_position != '\n' &&
                           *input_position != '\r') {
                        if (copied < limit) value[copied++] = *input_position;
                        input_position++;
                    }
                    value[copied] = '\0';
                    converted++;
                    break;
                }
                case '%':
                    if (*input_position++ != '%') return converted;
                    break;
                default:
                    return converted;
            }
        } else if (*format_position == ' ' || *format_position == '\t' ||
                   *format_position == '\n') {
            skip_space(&input_position);
        } else {
            if (*format_position != *input_position) break;
            input_position++;
        }
        format_position++;
    }

    return converted;
}

int c_test_scanf(const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = c_test_vscanf(format, arguments);
    va_end(arguments);
    return result;
}
