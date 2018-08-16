;FAT32 notes:
;Everything is little endian !

;First sector ($00000000) should be the MBR, check that $01FE = $55AA
;Wikipedia says we shouldn't rely on this signature for MBR presence check :(

;MBR:
;$000B (word) : bytes per sector, should be $0200 = 512 bytes	BYTESPERSECTOR          $200
;$000D (byte) : sectors per cluster, should be $08				SECTORSPERCLUSTER       $08
;$000E (word) : reserved sectors, very important, read !		RESERVED				$112E
;$0010 (byte) : number of FATs, should be 2 but read anyways !	FATCOUNT				$02
;$0015 (byte) : media descriptor, should be $F8					MEDIADESC				$F8
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

; This is done at startup in place of the CD Player screen setup to list the ISO files on the SD card
ParseSDFiles:
	move.b  #$FF,$FF0183		; REG_Z80RST, copied from original routine

	move.b  #0,MenuCursor
	move.b  #$80,MenuCursorPrev	; Force update (the MSB will be masked out)
	move.b  #0,MenuShift
	move.b  #0,ISOFilesCount

	; Clear ISO files list
	moveq.l #0,d0
	lea     ISOFilesList,a0
	move.w  #MAX_ISO_FILES,d7
.clear_iso_list:
	move.l  d0,(a0)+			; 16-byte entries
	move.l  d0,(a0)+
	move.l  d0,(a0)+
	move.l  d0,(a0)+
	subq.w  #1,d7
	bne     .clear_iso_list

	; Load the SD card's MBR (first sector)
	move.l  #0,SDLoadStart
	jsr     LoadRawSectorFromSD
	jsr		CheckSignature		; Check MBR signature

    ; Read first partition's start LBA
	lea     MBR_PSTARTLBA,a0
	jsr     GetLELongword
    lsl.l   #8,d0				; *512
    add.l   d0,d0
	move.l  d0,PARTITIONSTART	; $10200

	; Load the parition's boot record
	move.l  d0,SDLoadStart
	jsr     LoadRawSectorFromSD
	jsr		CheckSignature		; Check FAT32 boot record signature

	; Check "FAT32" string
	lea     FAT32_EBPBTYPE,a0
	lea     StrFAT32,a1
	jsr     CompareStrings
	beq     .fat32_ok
	moveq.l #9,d0				; Bad filesystem type
	jmp		ErrSD
.fat32_ok:
	
	; Load partition parameters
	lea     FAT32_BYTESPERSECT,a0
	jsr     GetLEWord
	move.w  d0,BYTESPERSECTOR
	move.b  FAT32_SECTPERCLUST,SECTORSPERCLUSTER
	lea     FAT32_RESERVEDSECT,a0
	jsr     GetLEWord
	move.w  d0,RESERVEDSECTORS
	move.b  FAT32_FATCOUNT,FATCOUNT
	move.b  FAT32_MEDIADESC,MEDIADESC
	lea     FAT32_SECTPERFAT,a0
	jsr     GetLELongword
	move.l  d0,FATSECTORS
	lea     FAT32_ROOTCLUSTER,a0
	jsr     GetLELongword
	move.l  d0,ROOTSTART

	; Display them
	; TODO ?
	
	; First FAT is located at PARTITIONSTART + (RESERVED * BYTESPERSECTOR)
	; ex. RESERVED = $112E, BYTESPERSECTOR = $0200, FAT is at $225C00 (NO! $235E00)
	moveq.l #0,d0
	move.w  RESERVEDSECTORS,d1
	move.w  BYTESPERSECTOR,d7
.do_mul0:
	add.l   d1,d0
	subq.w  #1,d7
	bne     .do_mul0
	add.l   PARTITIONSTART,d0
	move.l  d0,FATStart

	; Read partition's root directory
	; Located at PARTITIONSTART + (RESERVED + (FATSECTORS * FATCOUNT) + (ROOTSTART-2 * SECTORSPERCLUSTER)) * BYTESPERSECTOR
	moveq.l #0,d2
	move.b  FATCOUNT,d7			; $02 FATCOUNT should never be zero !
.do_mul1:
	add.l   FATSECTORS,d2		; $769
	subq.b  #1,d7
	bne     .do_mul1

	moveq.l #0,d0               ; d2 = $ED2
	move.l  ROOTSTART,d1
	subq.l  #2,d1
	move.b  SECTORSPERCLUSTER,d7
.do_mul2:
	beq     .mul2_done
	add.l   d1,d0
	subq.b  #1,d7
	bra     .do_mul2
	add.l   d0,d2
.mul2_done:              		; d2 = $ED2

    moveq.l #0,d0
	move.w  RESERVEDSECTORS,d0
	add.l   d0,d2               ; d2 = $2000

    moveq.l #0,d0
	move.w  BYTESPERSECTOR,d7	; If BYTESPERSECTOR is always 512, an optimization can be done here !
.do_mul3:
	add.l   d2,d0
	subq.w  #1,d7
	bne     .do_mul3           	; d0 = $400000, address of root directory in partition
	
	add.l   PARTITIONSTART,d0	; Make address absolute ($410200)
	move.l  d0,RootDirStart

	; Parse root directory
	move.l  d0,d2
	move.w  #MAX_ISO_FILES,d7
	lea     ISOFilesList,a2
	
.next_sector:
	; Load a root directory sector
	move.l  d2,SDLoadStart
	jsr     LoadRawSectorFromSD

	lea     SDSectorBuffer,a1
.parse_root:
	move.b  (a1),d0				; Get first byte of filename
	cmp.b   #0,d0
	beq     .root_end
	cmp.b   #$2E,d0				; Dot entry, ignore
	beq     .root_next
	cmp.b   #$E5,d0				; Deleted file, ignore
	beq     .root_next
	btst.b  #3,11(a1)     		; Attribute: Volume label, save aside
	bne     .vol_label
	btst.b  #4,11(a1)     		; Attribute: LFN entry, ignore
	bne     .root_next
	
	; Check if file extension is "ISO"
	cmp.b   #$49,8(a1)
	bne     .root_next
	cmp.b   #$53,9(a1)
	bne     .root_next
	cmp.b   #$4F,10(a1)
	bne     .root_next
	
	; Copy file name to ISO files list
	move.l  0(a1),0(a2)
	move.l  4(a1),4(a2)
	; Copy start cluster address
	lea     DIR_STARTCLUST_H(a1),a0
	jsr     GetLEWord
	move.w  d0,12(a2)
	lea     DIR_STARTCLUST_L(a1),a0
	jsr     GetLEWord
	move.w  d0,14(a2)

	addq.b  #1,ISOFilesCount

	subq.w  #1,d7
	beq     .root_end			; Max files reached
    lea     16(a2),a2

.root_next:
    lea     32(a1),a1
    cmpa.l  #SDSectorBuffer+512,a1
	bne     .parse_root
	; Ask for next sector
	addi.l  #512,d2
	bra     .next_sector
	
.vol_label:
	; Save volume label name
	move.l  0(a1),VOLUMELABEL
	move.l  4(a1),VOLUMELABEL+4
	bra     .root_next

.root_end:

	; Set up palette 3 for text
	lea     (2*16*3)+PALETTES,a0
	move.w  #BLACK,(a0)+
	move.w  #WHITE,(a0)+
	move.w  #BLACK,(a0)

	move.w  #$3000,FixWriteConfig

	; Display volume label
    lea     VOLUMELABEL,a0
    move.b  #0,8(a0)				; Terminate string
	move.w  #FIXMAP+7+(10*32),d0
	jsr     WriteFix
	
	jsr		DrawISOList

	move.b  #1,REG_ENVIDEO
	move.b  #0,REG_DISBLSPR
	move.b  #0,REG_DISBLFIX

    rts


CheckSignature:
	cmp.w   #$55AA,MBR_SIGNATURE
	beq     .sig_ok
	moveq.l #8,d0				; Bad signature
	jmp		ErrSD
.sig_ok:
	rts

; Get Little Endian Word
GetLEWord:
    move.b  1(a0),d0
    lsl.w   #8,d0
    move.b  (a0),d0
	rts
	
; Get Little Endian Longword
GetLELongword:
    move.b  3(a0),d0
    lsl.l   #8,d0
    move.b  2(a0),d0
    lsl.l   #8,d0
    move.b  1(a0),d0
    lsl.l   #8,d0
    move.b  (a0),d0
	rts
