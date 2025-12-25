ENTRY(_start)

SECTIONS
{
    /* Stage 2 starts at 0x20000. 
       Stage 2 is 4096 bytes (0x1000). 
       Therefore, Kernel starts at 0x21000. */
    . = 0x21000;

    .text : { *(.text) }
    .rodata : { *(.rodata) }
    .data : { *(.data) }
    .bss : { *(.bss) }
}