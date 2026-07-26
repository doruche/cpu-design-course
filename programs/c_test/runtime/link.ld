OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    rom  (rx)  : ORIGIN = 0x00000000, LENGTH = 50K
    ram1 (rwx) : ORIGIN = 0x0000C800, LENGTH = 50K
    ram2 (rwx) : ORIGIN = 0x00019000, LENGTH = 50K
}

SECTIONS
{
    .text : {
        KEEP(*(.text.start))
        *(.text .text.*)
    } > rom

    .rodata : {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    } > ram1

    .data : {
        *(.data .data.*)
        __global_pointer$ = . + 0x800;
        *(.sdata .sdata.*)
    } > ram1

    .bss (NOLOAD) : {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > ram1

    /DISCARD/ : {
        *(.comment)
        *(.eh_frame*)
    }

    _heap_start = ORIGIN(ram2);
    _stack_top = ORIGIN(ram2) + LENGTH(ram2);
}
