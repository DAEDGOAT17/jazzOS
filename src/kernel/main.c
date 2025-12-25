// A simple function to clear the screen and print "OS Loaded"
void kernel_main()
{
    // 0xB8000 is the address of the VGA text buffer
    char *video_mem = (char *)0xB8000;

    // Clear screen (set everything to space)
    for (int i = 0; i < 80 * 25 * 2; i += 2)
    {
        video_mem[i] = ' ';      // Character
        video_mem[i + 1] = 0x07; // Light gray on black
    }

    // Print "OS Loaded"
    char *message = "OS Loaded in C!";
    for (int i = 0; message[i] != '\0'; i++)
    {
        video_mem[i * 2] = message[i];
        video_mem[i * 2 + 1] = 0x0F; // White on black
    }
}