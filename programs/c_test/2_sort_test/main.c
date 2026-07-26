#include "peripheral.h"
#include <stdlib.h>
#include <string.h>

#ifndef C_TEST_STUDENT_ID
#error C_TEST_STUDENT_ID must be supplied by the repository build
#endif

void swap(int* a, int* b)
{
    int t = *a;
    *a = *b;
    *b = t;
}

int partition(int arr[], int low, int high)
{
    int pivot = arr[high];
    int i = (low - 1);
    
    for (int j = low; j <= high - 1; j++)
        if (arr[j] <= pivot)
            swap(&arr[++i], &arr[j]);

    swap(&arr[i + 1], &arr[high]);
    return i + 1;
}

void quick_sort(int arr[], int low, int high)
{
    if (low < high)
    {
        int pi = partition(arr, low, high);
        quick_sort(arr, low, pi - 1);
        quick_sort(arr, pi + 1, high);
    }
}

unsigned int fast_rand(unsigned int *seed)
{
    *seed = (*seed + 0x7A5B3C1D) ^ 0x12345678;
    return *seed;
}

#ifndef C_TEST_HOST
int main(void)
{
    uart_init();

    printf(C_TEST_STUDENT_ID " Test #2 - Sorting test:\n");

    /****** Phase 0 ******/
    printf("<Phase 0> - Fixed size sorting test:\n");

    printf("Enter 8 integers:\n");
    int arra[8];
    for (int i = 0; i < 8; i++) scanf("%d", &arra[i]);

    time_l start = get_time();
    quick_sort(arra, 0, 7);
    time_l end = get_time();

    printf("Sorted array:\n");
    for (int i = 0; i < 8; i++) printf("%d ", arra[i]);

    printf("\nTime consumed: ");
    c_test_print_time_ms(end - start);
    printf(" ms\n");

    /****** Phase 1 ******/
    printf("\n<Phase 1> - Malloc test:\n");

    int size;
    int* arra1;
    do {
        printf("Enter the size of the array:\n");
        scanf("%d", &size);
        if (size <= 0 || size > C_TEST_MAX_ARRAY_ITEMS) {
            arra1 = 0;
            printf("invalid size (expected 1..%d)\n", C_TEST_MAX_ARRAY_ITEMS);
            continue;
        }
        arra1 = (int*)malloc((unsigned int)size * sizeof(int));
        if (arra1 == 0)
            printf("malloc failed\nPlease input a smaller number\n");
    } while (arra1 == 0);

    memset(arra1, 0, size * sizeof(int));

    printf("array generated:\n");
    unsigned int seed = (unsigned int)get_time();
    for (int i = 0; i < size; i++)
    {
        arra1[i] = fast_rand(&seed) & 0xFF;
        printf("%d ", arra1[i]);
        if ((i & 0x7) == 7) printf("\n");
    }

    start = get_time();
    quick_sort(arra1, 0, size - 1);
    end = get_time();

    printf("\nSorted array:\n");
    for (int i = 0; i < size; i++)
    {
        printf("%d ", arra1[i]);
        if ((i & 0x7) == 7) printf("\n");
    }

    printf("\nTime consumed: ");
    c_test_print_time_ms(end - start);
    printf(" ms\n");

    free(arra1);

    printf("\nmalloc released.\n");
    return 0;
}
#endif
