#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <stdbool.h>

typedef struct
{
    uint8_t BS_jmpBoot[3];
    uint8_t BS_OEMName[8];
    uint16_t BPB_BytesPerSec;
    uint8_t BPB_SecPerClus;
    uint16_t BPB_ResvdSecCnt;
    uint8_t BPB_NumFATs;
    uint16_t BPB_RootEntCnt;
    uint16_t BPB_TotSec16;
    uint8_t BPB_Media;
    uint16_t BPB_FATSz16;
} __attribute__((packed)) bootsector;

typedef struct
{
    uint8_t DIR_Name[11];
    uint8_t DIR_Attr;
    uint8_t DIR_NTRes;
    uint8_t DIR_CrtTimeTenth;
    uint16_t DIR_CrtTime;
    uint16_t DIR_CrtDate;
    uint16_t DIR_LastAccDate;
    uint16_t DIR_FstClusHI;
    uint16_t DIR_WrtTime;
    uint16_t DIR_WrtDate;
    uint16_t DIR_FstClusLO;
    uint32_t DIR_FileSize;
} __attribute__((packed)) directory_entry;

FILE *g_DiskFile = NULL;
bootsector g_BootSector;
uint8_t *g_Fat = NULL;
directory_entry *g_RootDirectory = NULL;
uint32_t g_RootDirectoryEnd = 0;

bool read_boot_sector(void);
bool read_sectors(uint32_t lba, uint32_t count, void *data);
bool read_fat(void);
bool read_root_directory(void);
directory_entry *find_file(const char *filename);
uint8_t *read_file(directory_entry *entry);

bool read_sectors(uint32_t lba, uint32_t count, void *data)
{
    uint32_t offset = lba * g_BootSector.BPB_BytesPerSec;

    if (fseek(g_DiskFile, offset, SEEK_SET) != 0)
    {
        perror("Failed to seek in disk image");
        return false;
    }

    uint32_t bytes_to_read = count * g_BootSector.BPB_BytesPerSec;
    if (fread(data, 1, bytes_to_read, g_DiskFile) != bytes_to_read)
    {
        perror("Failed to read sectors from disk image");
        return false;
    }

    return true;
}

bool read_boot_sector(void)
{
    if (fread(&g_BootSector, 1, sizeof(g_BootSector), g_DiskFile) != sizeof(g_BootSector))
    {
        perror("Failed to read boot sector");
        return false;
    }
    return true;
}

bool read_fat(void)
{
    uint32_t fat_start_lba = g_BootSector.BPB_ResvdSecCnt;
    uint32_t fat_sectors = g_BootSector.BPB_FATSz16;
    uint32_t fat_size_bytes = fat_sectors * g_BootSector.BPB_BytesPerSec;
    
    g_Fat = (uint8_t *)malloc(fat_size_bytes);
    if (!g_Fat)
    {
        perror("Failed to allocate memory for FAT");
        return false;
    }

    if (!read_sectors(fat_start_lba, fat_sectors, g_Fat))
    {
        free(g_Fat);
        g_Fat = NULL;
        return false;
    }

    printf("FAT read successfully. Size: %u bytes\n", fat_size_bytes);
    return true;
}

bool read_root_directory(void)
{
    uint32_t root_dir_start_lba = g_BootSector.BPB_ResvdSecCnt +
                                  (g_BootSector.BPB_NumFATs * g_BootSector.BPB_FATSz16);

    uint32_t root_dir_size_bytes = g_BootSector.BPB_RootEntCnt * sizeof(directory_entry);
    uint32_t bytes_per_sec = g_BootSector.BPB_BytesPerSec;
    uint32_t root_dir_sectors = (root_dir_size_bytes + bytes_per_sec - 1) / bytes_per_sec;
    uint32_t buffer_size = root_dir_sectors * bytes_per_sec;
    
    g_RootDirectory = (directory_entry *)malloc(buffer_size);
    if (!g_RootDirectory)
    {
        perror("Failed to allocate memory for root directory");
        return false;
    }

    if (!read_sectors(root_dir_start_lba, root_dir_sectors, g_RootDirectory))
    {
        free(g_RootDirectory);
        g_RootDirectory = NULL;
        return false;
    }

    g_RootDirectoryEnd = root_dir_start_lba + root_dir_sectors;

    printf("Root Directory read successfully. Sectors: %u\n", root_dir_sectors);
    return true;
}

directory_entry *find_file(const char *filename)
{
    uint32_t num_entries = g_BootSector.BPB_RootEntCnt;

    for (uint32_t i = 0; i < num_entries; i++)
    {
        directory_entry *entry = &g_RootDirectory[i];

        if (memcmp(entry->DIR_Name, filename, 11) == 0)
        {
            printf("File '%s' found.\n", filename);
            return entry;
        }
    }

    return NULL;
}

uint8_t *read_file(directory_entry *entry)
{
    uint32_t bytes_per_cluster = g_BootSector.BPB_SecPerClus * g_BootSector.BPB_BytesPerSec;
    uint32_t file_size = entry->DIR_FileSize;
    uint32_t current_cluster = entry->DIR_FstClusLO;

    uint8_t *buffer = (uint8_t *)malloc(file_size + bytes_per_cluster);
    if (!buffer)
    {
        perror("Failed to allocate memory for file buffer");
        return NULL;
    }
    uint8_t *buffer_pos = buffer;

    printf("Reading file of size %u bytes. Starting cluster: %u\n", file_size, current_cluster);

    while (current_cluster < 0xFF8)
    {
        uint32_t cluster_lba = g_RootDirectoryEnd + (current_cluster - 2) * g_BootSector.BPB_SecPerClus;

        if (!read_sectors(cluster_lba, g_BootSector.BPB_SecPerClus, buffer_pos))
        {
            free(buffer);
            return NULL;
        }

        buffer_pos += bytes_per_cluster;

        uint32_t fat_offset = current_cluster * 3 / 2;
        uint16_t next_cluster_raw = *(uint16_t *)&g_Fat[fat_offset];
        uint16_t next_cluster;

        if (current_cluster % 2 == 0)
        {
            next_cluster = next_cluster_raw & 0x0FFF;
        }
        else
        {
            next_cluster = next_cluster_raw >> 4;
        }

        current_cluster = next_cluster;
    }

    return buffer;
}

int main(int argc, char *argv[])
{
    if (argc != 3)
    {
        fprintf(stderr, "Syntax: %s <disk_image> <filename_8.3_caps_padded>\n", argv[0]);
        return 1;
    }

    g_DiskFile = fopen(argv[1], "rb");
    if (!g_DiskFile)
    {
        perror("Failed to open disk image");
        return 1;
    }

    if (!read_boot_sector())
    {
        fclose(g_DiskFile);
        return 1;
    }

    if (!read_fat())
    {
        fclose(g_DiskFile);
        return 1;
    }

    if (!read_root_directory())
    {
        fclose(g_DiskFile);
        return 1;
    }

    directory_entry *file_entry = find_file(argv[2]);

    if (!file_entry)
    {
        fprintf(stderr, "Error: File '%s' not found.\n", argv[2]);
        fclose(g_DiskFile);
        return 1;
    }

    uint8_t *file_content = read_file(file_entry);

    if (file_content)
    {
        printf("\n--- File Content (%u bytes) ---\n", file_entry->DIR_FileSize);
        for (uint32_t i = 0; i < file_entry->DIR_FileSize; i++)
        {
            if (isprint(file_content[i]))
            {
                putchar(file_content[i]);
            }
            else
            {
                printf("\\x%02X", file_content[i]);
            }
        }
        printf("\n------------------------------\n");

        free(file_content);
    }

    free(g_RootDirectory);
    free(g_Fat);
    fclose(g_DiskFile);

    return 0;
}
