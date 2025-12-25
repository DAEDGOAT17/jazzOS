#!/bin/bash

# 1. Build the project to ensure we are debugging the latest code
make all

# 2. Launch QEMU with debugging flags:
# -s: Shorthand for -gdb tcp::1234 (opens debugger port)
# -S: Freeze CPU at startup (wait for debugger to say 'continue')
# -d int,cpu_reset: Log interrupts and CPU resets to a log file
# -no-reboot: Stop the flickering loop so we can see the crash state
qemu-system-i386 -fda build/main_floppy.img \
                 -s -S \
                 -d int,cpu_reset \
                 -D build/qemu.log \
                 -no-reboot \
                 -no-shutdown &

# 3. Launch GDB and connect to QEMU
# We point it to the kernel.elf if you have one, 
# but for raw binaries, we just connect.
gdb -ex "target remote localhost:1234" \
    -ex "set architecture i386" \
    -ex "layout src" \
    -ex "continue"