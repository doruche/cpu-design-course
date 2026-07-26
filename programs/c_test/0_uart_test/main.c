#include "../runtime/c_test_identity.h"

#define SW_BASE   0xFFFF0000
#define LED_BASE  0xFFFF1000
#define DLED_BASE 0xFFFF2000
#define UART_BASE 0xFFFF3000

#ifdef C_TEST_HOST
extern unsigned int c_test_mmio_read(unsigned int address);
extern void c_test_mmio_write(unsigned int address, unsigned int value);
#else
static unsigned int c_test_mmio_read(unsigned int address)
{
    return *(volatile unsigned int *)address;
}

static void c_test_mmio_write(unsigned int address, unsigned int value)
{
    *(volatile unsigned int *)address = value;
}
#endif

/*  | offset | registers        |       | stat_reg | description             |      | ctrl_reg | description      |
    |--------+------------------+       |----------+-------------------------|      |----------+------------------|
    |  0x00  | rx fifo          |       | bit3     | 1: tx fifo is full      |      | bit1     | 1: clear rx fifo |
    |  0x04  | tx fifo          |       | bit2     | 1: tx fifo is empty     |      | bit0     | 1: clear tx fifo |
    |  0x08  | status register  |       | bit1     | 1: rx fifo is full      |
    |  0x0C  | control register |       | bit0     | 1: rx fifo is not empty |
*/

void uart_init(void)
{
    c_test_mmio_write(UART_BASE + 0xC, 0x3);
}

void uart_putc(char c)
{
    while (c_test_mmio_read(UART_BASE + 0x8) & (1u << 3)) {
    }
    c_test_mmio_write(UART_BASE + 0x4, (unsigned char)c);
}

char uart_getc(void)
{
    while (!(c_test_mmio_read(UART_BASE + 0x8) & (1u << 0))) {
    }
    return (char)c_test_mmio_read(UART_BASE);
}

void print_str(char* str)
{
    while (*str) uart_putc(*str++);
}

int main()
{
    uart_init();

    print_str(C_TEST_UART_GUARD "\n\r"
              C_TEST_STUDENT_ID " Test #0 - UART simple test:\n\r");
    print_str("<Phase 0> - Output test:\n\r");
    print_str("Hello World!\n\r");

    print_str("\n\r<Phase 1> - Input test:\n\r");
    char ch;
    while (1)
    {
        print_str("Enter a char: ");
        ch = uart_getc();

        print_str("Input received: ");
        uart_putc(ch);
        print_str("\n\r");

        // 在数码管和LED显示字符的ASCII码
        c_test_mmio_write(LED_BASE, (unsigned char)ch);
        c_test_mmio_write(DLED_BASE, (unsigned char)ch);

        // 拨码开关为0时结束测试
        if (c_test_mmio_read(SW_BASE) == 0)
        {
            print_str("Test ended.");
            break;
        }
    }

    return 0;
}
