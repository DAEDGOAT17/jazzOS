
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef uint8_t bool;
#define true 1
#define false 0

typedef struct
{
    uint8_t BootJumpInstruction[3];
    uint8_t OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    uint8_t DriveNumber;
    uint8_t _Reserved;
    uint8_t Signature;
    uint32_t VolumeId;       // serial number, value doesn't matter
    uint8_t VolumeLabel[11]; // 11 bytes, padded with spaces
    uint8_t SystemId[8];

} __attribute__((packed)) BootSector;

typedef struct
{
    uint8_t Name[11];
    uint8_t Attributes;
    uint8_t _Reserved;
    uint8_t CreatedTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreatedDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;
} __attribute__((packed)) DirectoryEntry; // in order to make the padding provided by the compiler go away

BootSector g_bootsector;
DirectoryEntry *rootdirectoryentry = NULL;
uint8_t *g_fat = NULL;

bool readbootsector(FILE *disk)
{
    return fread(&g_bootsector, sizeof(g_bootsector), 1, disk) > 0;
}

bool readsectors(FILE *disk, uint32_t lba, uint32_t count, void *bufferout)
{ // to read the sectors  or to simulate that reading

    bool ok = true;
    ok = ok && (fseek(disk, lba * g_bootsector.BytesPerSector, SEEK_SET) == 0);
    ok = ok && (fread(bufferout, g_bootsector.BytesPerSector, count, disk) == count);
    return ok;
}

bool readFat(FILE *disk)
{
    g_fat = (uint8_t *)malloc(g_bootsector.SectorsPerFat * g_bootsector.BytesPerSector);
    return readsectors(disk, g_bootsector.ReservedSectors, g_bootsector.SectorsPerFat, g_fat);
}

bool readrootdirectory(FILE *disk)
{
    uint32_t lba = g_bootsector.ReservedSectors + g_bootsector.SectorsPerFat * g_bootsector.FatCount;
    uint32_t size = g_bootsector.DirEntryCount * sizeof(DirectoryEntry);
    uint32_t sectors = size / g_bootsector.BytesPerSector;
    if (size % g_bootsector.BytesPerSector > 0)
    {
        sectors++;
    }

    rootdirectoryentry = ((DirectoryEntry *)malloc(sectors * g_bootsector.BytesPerSector));
    return readsectors(disk, lba, sectors, rootdirectoryentry);
}

DirectoryEntry *find_file(const char *name)
{
    for (uint32_t i = 0; i < g_bootsector.DirEntryCount; i++)
    {
        if (memcmp(name, rootdirectoryentry[i].Name, 11) == 0)
        {
            // ittratte over all the dir entry to find the actual file
            printf("Found file: %.*s\n", 11, rootdirectoryentry[i].Name);
            return &rootdirectoryentry[i];
        }
    }
    return NULL;
}

int main(int argc, char *argv[])
{ // main function to open the file if the command is correct
    if (argc < 3)
    {
        printf("syntax %s is <disk image>  <file name>", argv[0]);
        return -1;
    }

    FILE *disk = fopen(argv[1], "rb");

    if (!disk)
    {
        fprintf(stderr, "cannot read the disk %s \n", argv[1]);
        return -1;
    }

    if (!readbootsector(disk))
    {
        fprintf(stderr, "failed to read a boot sector\n");
        return -2;
    }

    if (!readFat(disk))
    {
        fprintf(stderr, "failed to read a fat\n");
        return -3;
    }

    if (!readrootdirectory(disk))
    {
        fprintf(stderr, "failed to read a root directory\n");
        return -4;
    }

    DirectoryEntry *fileentry = find_file(argv[2]);
    if (!fileentry)
    {
        fprintf(stderr, "failed to find the file in the root directory %s\n", argv[2]);
        free(g_fat);
        free(rootdirectoryentry);
        return -5;
    }

    free(g_fat);
    free(rootdirectoryentry);
    fclose(disk);
    return 0;
}
