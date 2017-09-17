;FAT32 notes:
;Everything is little endian !

;First sector ($00000000) should be the MBR, check that $01FE = $55AA
;Wikipedia says we shouldn't rely on this signature for MBR presence check :(

;MBR:
;$000B (word) : bytes per sector, should be $0200 = 512 bytes	BYTESPERSECTOR
;$000D (byte) : sectors per cluster, should be $08				SECTORSPERCLUSTER
;$000E (word) : reserved sectors, very important, read !		RESERVED				$112E
;$0010 (byte) : number of FATs, should be 2 but read anyways !	FATCOUNT
;$0015 (byte) : media descriptor, should be $F8					MEDIADESC
;$0024 (long) : FAT size in sectors								FATSECTORS				$00000769
;$002C (long) : Root directory start in clusters				ROOTSTART				$00000002
;$0052 (str)  : Should be "FAT32"								Don't store

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

LoadSDSector:
	move.b  d0,REG_DIPSW

	move.w  #$00FF,d0			; CS low, high speed, data all ones

	movea.l #SDREG_HIGHSPEED,a0	; Speed switch
	btst.l  #8,d0
    beq     .fast
	movea.l #SDREG_LOWSPEED,a0
.fast:
    move.w  (a0),d4

	movea.l #SDREG_CSHIGH,a0	; CS switch
	btst.l  #9,d0
    bne     .cs_high
	movea.l #SDREG_CSLOW,a0
.cs_high:
    move.w  (a0),d4

	;movea.l #SDREG_DOUTBASE,a0	; TODO: a0 can be replaced by fixed value
	;lsl.w   #1,d0
	;andi.l  #$1FE,d0
	;adda.l  d0,a0

	move.w  SDREG_INITBURST,d4	; d4 is throw-away

	move.w  #64,d6 				; Read whole SD sector (512 bytes)
.readsector:
	move.b  d0,REG_DIPSW
	;move.w  (a0),d4				; SPI "Write"
	move.b  SDREG_DIN,(a1)+		; SPI read
	;nop
	;move.w  (a0),d4				; SPI "Write"
	move.b  SDREG_DIN,(a1)+		; SPI read
	;nop
	;move.w  (a0),d4				; SPI "Write"
	move.b  SDREG_DIN,(a1)+		; SPI read
	;nop
	;move.w  (a0),d4				; SPI "Write"
	move.b  SDREG_DIN,(a1)+		; SPI read
	;nop
	;move.w  (a0),d4				; SPI "Write"
	move.b  SDREG_DIN,(a1)+		; SPI read
	;nop
	;move.w  (a0),d4				; SPI "Write"
	move.b  SDREG_DIN,(a1)+		; SPI read
	;nop
	;move.w  (a0),d4				; SPI "Write"
	move.b  SDREG_DIN,(a1)+		; SPI read
	;nop
	;move.w  (a0),d4				; SPI "Write"
	move.b  SDREG_DIN,(a1)+		; SPI read
	;nop
	subq.w  #1,d6
	bne     .readsector
	rts       


LoadCDSectorFromSD:
    movem.l d0-d7/a0-a6,-(sp)
	move.b  d0,REG_DIPSW

	moveq.l #4,d7
	lea     $111204,a1			; "CDSectorBuffer"

.readsectors:

	move.w  #$0011,d0			; CS low, high speed, CMD17 (17 = $11)
	move.l  SDLoadStart,d2
	jsr     SDCommand
	jsr     GetR1
	tst.b   d0
	beq     .cmdreadok
	moveq.l #6,d0				; Error step 6: CMD17 wasn't accepted
	jmp		ErrSD
.cmdreadok:

	; Wait for data token
	moveq.l #100,d6				; Max tries
.try:
	move.b  d0,REG_DIPSW
	move.w  #$00FF,d0			; CS low, high speed, data all ones
	jsr     PutByteSPI
	cmp.b   #$FE,d0
	beq     .gottoken
	subq.b  #1,d6
	bne     .try
	moveq.l #7,d0				; Error step 7: Didn't get the data token in time
	jmp		ErrSD
.gottoken:

	;move.w  #512,d6 			; Read SD sector
;.readonesector:
	;move.w  #$00FF,d0			; CS low, high speed, data all ones
	jsr     LoadSDSector

	;move.b  d0,(a1)+
	;subq.w  #1,d6
	;bne     .readonesector

	move.w  #$00FF,d0			; Discard CRC
	jsr     PutByteSPI
	move.w  #$00FF,d0
	jsr     PutByteSPI

	move.w  #$0200,d0			; CS high
	jsr     PutByteSPI

	addi.l  #512,SDLoadStart

	subq.b  #1,d7
	tst.b   d7
	bne     .readsectors

	move.b  d0,REG_DIPSW
	move.b  BIOS_P1CURRENT,d0	; Stall and dump memory on C+D press during loading
    cmp.b   #$C0,d0
	bne     .go_on
	lea     $111204,a1			; Dump memory starting from "CDSectorBuffer" and lock up
	jmp     DumpMemory
.go_on:

	lea     FixValueList,a0
	move.l  SDLoadStart,(a0)+
    lea     FixStrCurAddr,a0
	move.w  #FIXMAP+12+(6*32),d0
	jsr     WriteFix            ; Display absolute address of loading start in SD card and Subsector (3~0)
	
	; For original progressbar update:
	move.b  d0,REG_DIPSW
	move.l  $10F690,d0
	add.l   $10F68C,d0
	cmpi.l  #$800000,d0
	bls     .nocap
	move.l  #$800000,d0
.nocap:
	move.l  d0,$10F690

    subq.w  #1,CDSectorCount
	move.w  CDSectorCount,$10F688

    movem.l (sp)+,d0-d7/a0-a6
    rts
