MAX_ISO_FILES	equ		32

FixValueList	equ		$10D000	; Longwords		List of values (max 7) used by WriteFix codes $F0+
ISOLoadStart	equ		$10D104 ; Longword		ISO file address for start of file to load
SDLoadStart		equ		$10D108 ; Longword		Absolute SD address for start of data to load
CDSectorCount	equ		$10D10C	; Word			Length of data to load (1 CD sector = 4 SD sectors)
CardType		equ		$10D10E	; Word			SD/MMC/SDHC Not used for now
PCERROR			equ		$10D110	; Longword		For error screen
FixWriteConfig	equ		$10D114 ; Word			ORed with fix tilemap data to set bank and palette
MenuCursor		equ		$10D116 ; Word			Menu cursor position
MenuCursorPrev	equ		$10D118 ; Word
RootDirStart	equ     $10D120 ; Longword		Absolute SD address for start of root directory
ISOFilesList	equ		$10D200	; 16-byte entries: filename (8), 0 (4), start cluster index (4)
SDSectorBuffer	equ		$10D500	; 512 bytes		Used when only one SD sector must be read

; FAT32 stuff:
BYTESPERSECTOR	equ		$10D800 ; Word
SECTORSPERCLUSTER	equ	$10D802 ; Byte
RESERVEDSECTORS	equ		$10D804 ; Word
FATCOUNT		equ		$10D806 ; Byte
MEDIADESC		equ		$10D808 ; Byte
FATSECTORS		equ		$10D810 ; Longword
ROOTSTART		equ		$10D814 ; Longword
PARTITIONSTART  equ     $10D820 ; Longword
VOLUMELABEL		equ		$10D824 ; 9 bytes

; Hoping these are never overwritten while a game runs :/
FATSectorBuffer	equ		$1F0000	; 512 bytes
FATStart      	equ     $1F0200 ; Longword		Absolute SD address for start of FAT
SDISOStart		equ     $1F0204 ; Longword		Absolute SD address for start of ISO file
ClusterIndex    equ     $1F0208 ; Longword		Used to keep track of the ISO file chain

; HW registers:
SDREG_DOUTBASE	equ		$C1E000
SDREG_CSLOW		equ		$C1E300
SDREG_CSHIGH	equ		$C1E310
SDREG_LOWSPEED	equ		$C1E400
SDREG_HIGHSPEED	equ		$C1E410
SDREG_UNLOCK	equ		$C1E500
SDREG_LOCK		equ		$C1E510
SDREG_STATUS	equ		$C1E600
SDREG_INITBURST equ		$C1E700
SDREG_DIN		equ		$C1E800
SDREG_DIN_WORD	equ		$C1E900
