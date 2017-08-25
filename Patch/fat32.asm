;FAT32 notes:
;Everything is little endian !

;First sector ($00000000) should be the MBR, check that $01FE = $55AA
;Wikipedia says we shouldn't rely on this signature for MBR presence check :(

;MBR:
;$000B (word) : bytes per sector, should be $0200 = 512 bytes	BYTESPERSECTOR
;$000D (byte) : sectors per cluster, should be $08				SECTORSPERCLUSTER
;$000E (word) : reserved sectors, very important, read !			RESERVED
;$0010 (byte) : number of FATs, should be 2 but read anyways !	FATCOUNT
;$0015 (byte) : media descriptor, should be $F8					MEDIADESC
;$0024 (long) : FAT size in sectors								FATSECTORS
;$002C (long) : Root directory start in clusters					ROOTSTART
;$0052 (str)  : Should be "FAT32"                                Don't store

;First FAT is located at (RESERVED * BYTESPERSECTOR)
;ex. RESERVED = $112E, BYTESPERSECTOR = $0200, FAT is at $225C00

;FAT:
;All entries are longwords
;0: FAT ID, the LSbyte should be == to MEDIADESC ($F8)
;1: Don't care
;2: Chain for root directory
;3: Chains for files...

;Root directory:
;Located at (RESERVED + (FATSECTORS * FATCOUNT) + (ROOTSTART-2 * SECTORSPERCLUSTER)) * BYTESPERSECTOR
;ex. RESERVED = $112E, FATSECTORS = $0769, FATCOUNT = $02, ROOTSTART = $02, BYTESPERSECTOR = $0200,
;	Root directory is at $400000

;Directory (root, ...):
;First 11 bytes are the filename and extension (8.3)
;If byte 0 == $00, end of directory list
;If byte 0 == $2E, "dot entry", ignore
;If byte 0 == $E5, deleted file/dir, ignore

;$000B (byte) : Attributes, bit3 = file name is actually the volume label
;							bit4 = subdir, ignore for now
;							If == $0F, it's an LFN, ignore whole entry for now
;$0014 (word) : HSbytes of first cluster number in FAT
;$001A (word) : LSbytes of first cluster number in FAT
;$001C (long) : File size in bytes

;ex. clusternumber = $0003 (entry number in FAT).
;    Entry $0003 in FAT is "$0004"
;	Root directory + (clusternumber - 3) * BYTESPERSECTOR * SECTORSPERCLUSTER (always -3 ?)
;	= $400000 + 1 * $0200 * $08 = $401000

LoadCDSectorFromSD:
    movem.l d0-d7/a0-a6,-(sp)
	move.b  d0,REG_DIPSW
	move.l  #4,d7
	lea     $111204,a1			; "CDSectorBuffer"
.readsectors:

	move.w  #$0011,d0			; CS low, high DEBUG!!! speed, CMD17 (17 = $11)
	move.l  SDLoadStart,d2
	jsr     SDCommand
	jsr     GetR1
	tst.b   d0
	beq     .cmdreadok
	moveq.l #6,d0				; Error step 6: CMD17 wasn't accepted
	jmp		Error
.cmdreadok:

	move.b  d0,REG_DIPSW		; Wait for data token
	moveq.l #100,d6				; Max tries
.try:
	move.w  #$00FF,d0			; CS low, high DEBUG!!! speed, data all ones
	jsr     PutByteSPI
	cmp.b   #$FE,d0
	beq     .gottoken
	subq.b  #1,d6
	bne     .try
	moveq.l #7,d0				; Error step 7: Didn't get the data token in time
	jmp		Error
.gottoken:

	move.w  #512,d6
.readonesector:
	move.w  #$00FF,d0			; CS low, high DEBUG!!! speed, data all ones
	jsr     PutByteSPI
	move.b  d0,(a1)+
	subq.w  #1,d6
	bne     .readonesector

	move.w  #$00FF,d0			; Discard CRC
	jsr     PutByteSPI
	move.w  #$00FF,d0
	jsr     PutByteSPI

	move.w  #$0200,d0			; CS high
	jsr     PutByteSPI

	subq.l  #1,d7
	addi.l  #512,SDLoadStart

    lea     FixValueList,a0
	move.l  SDLoadStart,(a0)
    lea     FixStrSDAddr,a0
	move.w  #FIXMAP+12+(6*32),d0
	jsr     WriteFix            ; Display absolute address of loading start in SD card

    lea     FixValueList,a0
	move.l  d7,(a0)
    lea     FixStrSubSecCnt,a0
	move.w  #FIXMAP+13+(6*32),d0
	jsr     WriteFix            ; Show that we've succefully loaded a new sector

	tst.l   d7
	bne     .readsectors
	
    subq.w  #1,CDSectorCount
	move.w  CDSectorCount,$10F688

    movem.l (sp)+,d0-d7/a0-a6
    rts
