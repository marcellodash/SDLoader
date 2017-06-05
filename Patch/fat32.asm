FAT32 notes:

Everything is little endian !

First sector ($00000000) should be the MBR, check that $01FE = $55AA
Wikipedia says we shouldn't rely on this signature for MBR presence check :(

MBR:

$000B (word) : bytes per sector, should be $0200 = 512 bytes	BYTESPERSECTOR
$000D (byte) : sectors per cluster, should be $08				SECTORSPERCLUSTER
$000E (word) : reserved sectors, very important, read !			RESERVED
$0010 (byte) : number of FATs, should be 2 but read anyways !	FATCOUNT
$0015 (byte) : media descriptor, should be $F8					MEDIADESC
$0024 (long) : FAT size in sectors								FATSECTORS
$002C (long) : Root directory start in clusters					ROOTSTART
$0052 (str)  : Should be "FAT32"                                Don't store

First FAT is located at (RESERVED * BYTESPERSECTOR)
ex. RESERVED = $112E, BYTESPERSECTOR = $0200, FAT is at $225C00

FAT:

All entries are longwords
0: FAT ID, the LSbyte should be == to MEDIADESC ($F8)
1: Don't care
2: Chain for root directory
3: Chains for files...

Root directory:

Located at (RESERVED + (FATSECTORS * FATCOUNT) + (ROOTSTART-2 * SECTORSPERCLUSTER)) * BYTESPERSECTOR
ex. RESERVED = $112E, FATSECTORS = $0769, FATCOUNT = $02, ROOTSTART = $02, BYTESPERSECTOR = $0200,
	Root directory is at $400000

Directory (root, ...):

First 11 bytes are the filename and extension (8.3)
If byte 0 == $00, end of directory list
If byte 0 == $2E, "dot entry", ignore
If byte 0 == $E5, deleted file/dir, ignore

$000B (byte) : Attributes, bit3 = file name is actually the volume label
							bit4 = subdir, ignore for now
							If == $0F, it's an LFN, ignore whole entry for now
$0014 (word) : HSbytes of first cluster number in FAT
$001A (word) : LSbytes of first cluster number in FAT
$001C (long) : File size in bytes

ex. clusternumber = $0003 (entry number in FAT).
	Root directory + (clusternumber - 2) * BYTESPERSECTOR * SECTORSPERCLUSTER (always -2)
	= $400000 + 1 * $0200 * $08 = $401000
