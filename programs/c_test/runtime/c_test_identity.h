#ifndef C_TEST_IDENTITY_H
#define C_TEST_IDENTITY_H

#ifndef C_TEST_STUDENT_ID
#define C_TEST_STUDENT_ID "2024311488"
#endif

/* The course downloader can drop the first TX byte after handing off UART. */
#define C_TEST_UART_GUARD " "

#endif
