    cpu 68000
    supmode on
    INCLUDE "regdefs.asm"
	INCLUDE "equ.asm"
    INCLUDE "vectors.asm"
	INCLUDE "splash.asm"

	; !!! See doc.odt !!!

	INCLUDE "patches.asm"

	; New code starts from here ---------------------------

	ORG $C19000
PUPPETStuff:
	move.w  #0,($FF0000).l		; Copied from original routine OK, required for PUPPET init
	move.w  #$550,($FF0002).l
    move.w  #$731,($FF0004).l
    move.b  #$FE,($FF0011).l
    move.b  #$3C,($FF000E).l
	move.w  #7,(REG_IRQACK).l
	andi.w  #$F8FF,sr

	move.w  #$0000,FixWriteConfig 	; Added

	jsr     InitSD                  ; Added
	rts
	

CDPlayerVBLProc:
    jsr     $C0E9A0 			; CDPControllerStuff, copied from original routine
    
    ; Handle input to allow selection of ISO file from list
    move.b  BIOS_P1CHANGE,d0

	btst    #0,d0
    beq     .no_up
    tst.w   MenuCursor
    beq     .no_up
    subq.w  #1,MenuCursor
.no_up:

	btst    #1,d0
    beq     .no_down
    cmp.w   #16,MenuCursor		; TODO: Change max
    beq     .no_down
    addq.w  #1,MenuCursor
.no_down:

	move.w  MenuCursorPrev,d0
	cmp.w   MenuCursor,d0
	beq     .no_redraw
	andi.w  #$00FF,d0
	; Erase previous cursor
	add.w  #FIXMAP+9+(9*32),d0
	move.w  d0,REG_VRAMADDR
	nop
	nop
	move.w  #$3020,REG_VRAMRW	; Space, palette 3
	; Draw new cursor
	move.w  #FIXMAP+9+(9*32),d0
	add.w   MenuCursor,d0
	move.w  d0,REG_VRAMADDR
	nop
	nop
	move.w  #$3011,REG_VRAMRW	; Arrow pointing right, palette 3
	move.w  MenuCursor,MenuCursorPrev
.no_redraw:

    move.b  BIOS_P1CHANGE,d0
	btst    #4,d0
    beq     .no_a
    ; Load selected ISO !
    ; Don't do the "CD001", .TXT files checks... for now
    ; Get the first cluster index
	lea     ISOFilesList,a0
	move.w  MenuCursor,d0
	lsl.w   #4,d0				; ISOFilesList has 16-byte entries
	move.l  12(a0,d0),d0        ; $10D20C ok
	add.l   d0,d0				; FAT32 has 4-byte cluster entries
	add.l   d0,d0
	add.l   FATStart,d0			; Beginning of FAT $235E00 ok
	move.l  d0,d1
	; Load the appropriate FAT sector
	andi.l  #$FFFFFE00,d0
	move.l  d0,SDLoadStart
	jsr     LoadRawSectorFromSD
	; Get ISO file's first cluster number MSLUG.ISO should be #4
	andi.l  #$000001FF,d1
	lea     SDSectorBuffer,a0
	adda.l  d1,a0
	jsr     GetLELongword		; $4 ok
	move.l  d0,d1

	; Compute absolute address for ISO file start
	; Root directory + (clusternumber - 3) * BYTESPERSECTOR * SECTORSPERCLUSTER
	subq.l  #3,d1				; d1 = 1

    moveq.l #0,d0
	move.w  BYTESPERSECTOR,d7	; If BYTESPERSECTOR is always 512, an optimization can be done here !
.do_mul0:
	add.l   d1,d0
	subq.w  #1,d7
	bne     .do_mul0			; d0 = $200
	
	move.l  d0,d1
    moveq.l #0,d0
	move.b  SECTORSPERCLUSTER,d7
.do_mul1:
	add.l   d1,d0
	subq.b  #1,d7
	bne     .do_mul1			; d0 = $1000

	add.l   RootDirStart,d0		; d0 = $411200 (sector 8329)
	move.l  d0,SDISOStart		; "CD001" is at sector 8393 ($419200)

	jsr     $C0EB96				; CheckCDValid
	btst   	#7,$10F656			; "CDValidFlag"
	beq     .invalid
	move.b  #$80,$10F6B9		; "GameStartState" Kickstart loading
.invalid:
.no_a:

	btst   	#7,$10F6B9			; "GameStartState"
	beq     .idle
	jmp     $C0EB44				; StartGameCD
.idle:

	rts


InitRAM:
	st.b    $7E85(a5)			; MSFMismatchCntr to make Robo Army happy
	clr.l   $775C(a5)			; CDLidCompareB - Copied from original routine
    rts


LoadFile:
	jsr     DebugDispFileName

	moveq.l #0,d0				; Copied from original routine
    move.b  $10F6C2,d0			; "FileTypeCode"
    lsl.b   #2,d0
    lea     $C0F60A,a0			; "JTFileLoaders"
    movea.l 0(a0,d0),a0
    jmp     (a0)


CDCheckDone:
	btst   	#7,$10F656			; "CDValidFlag"
	bne     .valid
	lea     $111204,a1			; Dump memory starting from "CDSectorBuffer" and lock up
	bra     MemoryViewer
.valid:
	clr.b   $10F6B6				; Original code "CDLoadBusy"
	bclr    #0,$7656(a5)		; Original code "CDValidFlag"
	jmp     $C0EE4E				; Return to original code


LoadFromCD:
    movem.l d0-d7/a0-a6,-(sp)	; LoadFromCD jump patch
    
    ; This is copied from the original code
    move.b  #1,$76B6(a5)
    clr.b   $76B7(a5)
    ;Ignore PushCDOp
	move.w  #4,$7684(a5)
	move.b  #64,$76BA(a5)
	move.b  #64,$76BB(a5)
	clr.w   $76BC(a5)
	move.w  #$550,$FF0002
	move.b  #1,$FF0101
	move.b  #%11100010,$FF0103
	move.b  #$A,$FF0101
	move.b  #%10100111,$FF0103
	move.b  #%11110000,$FF0103

    ; Set up palettes for text
	move.b  d0,REG_DIPSW
	lea     PALETTES,a0
	move.w  #BLACK,(a0)+
	move.w  #WHITE,(a0)+
	move.w  #BLACK,(a0)

	move.b  #1,REG_ENVIDEO
	move.b  #0,REG_DISBLSPR
	move.b  #0,REG_DISBLFIX

	jsr     DebugDispMSF

    ; Convert MSF to LBA in iso file
	lea     $10F6C8,a0
	moveq.l #0,d3
	move.b  (a0)+,d0			; M
	jsr     BCDtoHex
	mulu.w  #75*60,d0
	add.l   d0,d3
	move.b  (a0)+,d0			; S
	jsr     BCDtoHex
	mulu.w  #75,d0
	add.l   d0,d3
	move.b  (a0)+,d0			; F
	jsr     BCDtoHex
	add.l   d0,d3
	subi.l  #2*75,d3			; Remove 2 second gap
	lsl.l   #8,d3				; Absolute hex address in ISO file (CD sector = 2048 bytes)
	lsl.l   #3,d3
	move.l  d3,ISOLoadStart
	move.b  d0,REG_DIPSW

	jsr     DebugDispISOAddr

	move.w  $10F688,d0			; Retrieve requested sector count to load
	move.w  d0,CDSectorCount	; Make our own copy, just in case

	jsr		DebugDispCDSectors

	; Partition start is longword at 0x1C * sector size ? ex: 0x81*0x0200 = 10200
	move.l  SDISOStart,d0
	add.l   ISOLoadStart,d0
	move.l  d0,SDLoadStart

	jsr		DebugDispSDAddr

	; Stop any previous multiple-read
	; TODO: Probably not necessary to try multiple times
	move.w  #$010C,d0			; CS low, high speed, CMD12
	moveq.l #0,d2
	jsr     SDCommand
	moveq.l #200,d6				; Max tries
.trystop:
	move.b  d0,REG_DIPSW
	move.w  #$01FF,d0			; CS low, high speed, data all ones
	jsr     PutByteSPI
	cmp.b   #$FF,d0
	beq     .notbusy
	subq.b  #1,d6
	bne     .trystop
	moveq.l #6,d0				; CMD12 failed
	jmp		ErrSD
.notbusy:

	; Start new multiple-read
	move.w  #$0112,d0			; CS low, high speed, CMD18 (18 = $12)
	move.l  SDLoadStart,d2
	jsr     SDCommand
	jsr     GetR1
	tst.b   d0
	beq     .cmdreadok
	moveq.l #7,d0				; CMD18 wasn't accepted
	jmp		ErrSD
.cmdreadok:

    movem.l (sp)+,d0-d7/a0-a6
	rts

	INCLUDE "debug.asm"
	INCLUDE "copy.asm"
	INCLUDE "util.asm"
    INCLUDE "exceptions.asm"
	INCLUDE "print.asm"
	INCLUDE "sdcard.asm"
	INCLUDE "fat32.asm"
	INCLUDE "strings.asm"

	padding on

	ORG $C20C10   				; Replace palette #3 during loading screen (for debug text)
	dc.w BLACK, WHITE, BLACK

	ORG $C6DEB0
	BINCLUDE "fix_alphabet_bank.bin"

    ORG $C6FEB0
	BINCLUDE "sprites.bin"
