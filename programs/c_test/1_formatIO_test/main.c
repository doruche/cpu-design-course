#include "peripheral.h"

#ifndef C_TEST_STUDENT_ID
#error C_TEST_STUDENT_ID must be supplied by the repository build
#endif

#define LED_BASE  0xFFFF1000
#define DLED_BASE 0xFFFF2000

#ifdef C_TEST_HOST
extern void c_test_mmio_write(unsigned int address, unsigned int value);
#else
static void c_test_mmio_write(unsigned int address, unsigned int value)
{
    *(volatile unsigned int *)address = value;
}
#endif

int main()
{
    uart_init();

    printf(C_TEST_STUDENT_ID " Test #1 - Formatted input/output test:\n");
    
    /****** Phase 0 ******/
    printf("<Phase 0> - Formatted output test:\n");
    printf("%d\n0x%x\n%c\n%s\n%f\n", 123, 0x456, 'c', "Hello World!", 98.7654);

    /****** Phase 1 ******/
    printf("\n<Phase 1> - Formatted input test:\n");
    int  input_int;
    char input_ch;
    char input_str[64];
    while (1)
    {
        printf("Enter an integer, a char, and a string (e.g., 123 x hello): \n");
        scanf("%d %c %63s", &input_int, &input_ch, input_str);
        printf("Input received: int=%d, char='%c', string=\"%s\"\n", input_int, input_ch, input_str);
        if (input_str[0] == 'e' && input_str[1] == 'n' && input_str[2] == 'd' && input_str[3] == '\0')
        {
            printf("Test ended.");
            break;
        }

        // input_int 是负数时，最低位LED点亮；数码管显示绝对值
        unsigned int magnitude = input_int < 0
            ? 0u - (unsigned int)input_int : (unsigned int)input_int;
        c_test_mmio_write(LED_BASE, input_int < 0 ? 1u : 0u);
        c_test_mmio_write(DLED_BASE, magnitude);
    }

    return 0;
}
