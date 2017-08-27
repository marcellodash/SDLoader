    cpu 68000
    supmode on
    INCLUDE "regdefs.asm"

    INCLUDE "vectors.asm"

	INCLUDE "splash.asm"

FixValueList	equ		$10E000	; OK ?
SDISOStart		equ		$10E100	; Longword
ISOLoadStart	equ		$10E104 ; Longword
SDLoadStart		equ		$10E108 ; Longword
CDSectorCount	equ		$10E10C	; Word
SDSectorCount	equ		$10E110	; Longword

FixWriteConfig	equ		$10E120 ; Word

PCERROR			equ		$10E200	; Longword

; HW registers:
SDREG_DOUTBASE	equ		$C1E000
SDREG_CSLOW		equ		$C1E300
SDREG_CSHIGH	equ		$C1E310
SDREG_LOWSPEED	equ		$C1E400
SDREG_HIGHSPEED	equ		$C1E410
SDREG_UNLOCK	equ		$C1E500
SDREG_LOCK		equ		$C1E510
SDREG_STATUS	equ		$C1E600
SDREG_DIN		equ		$C1E800


    ORG $C0C360
	nop							; Disable lid check and CD track operations in vblank handler
	nop
	nop
	nop

    ORG $C0C854
	jmp     PUPPETStuff			; Called at startup

	ORG $C0E712
	jmp     DrawProgressAnimation	; Don't draw loading progress animation

	;ORG $C0E8BE
	;nop							; Auto push start, to start the game directly

	ORG $C0E8D2
	bra     $C0E968				; Skip CD player interface updating

	ORG $C0EB96
	nop                         ; Disable CD mech detection in CheckCDValid
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	ORG $C0EBC8
	nop							; Disable "WAIT A MOMENT" message
	nop

	ORG $C0EBF2
	nop							; Disable "WAIT A MOMENT" message (again)
	nop

	ORG $C0EBF8
	nop							; Disable PUPPET CD mode activation
	nop

	ORG $C0EC16
	jsr     LoadCDSectorFromSD
	move.b  d0,REG_DIPSW
	bra     $C0EC3A				; Skip first sector loading wait, there's no more CD :)

	ORG $C0EDA2
	bra     $C0EE00             ; Prevent loading custom loading screens

	ORG $C0EE04
	nop							; Bypass CD lid check

    ORG $C0EE0C
	jmp     CDCheckDone

	ORG $C0EF4C
	tst.w   $10F688				; "SectorCounter"
	beq     $C0EFD0				; rts
	jsr     LoadCDSectorFromSD
	bra     $C0EF66

	ORG $C0EF6C					; Bypass CD lid check
	nop
	nop
	nop

	ORG $C0F0AE					; Disable waiting for CD to stop after game load
	nop
	nop

	ORG $C0F4E8					; Disable waiting for CD to stop after BIOSF_LOADFILE
	nop
	nop

	ORG $C0F324
	bra     $C0F348				; Prevent loading custom loading screens
	ORG $C0F382
	bra     $C0F3AA             ; Same

	ORG $C0F5FC
	jmp     LoadFile			; Patch original LoadFile

	ORG $C0FD78
	jsr     LoadCDSectorFromSD
	bra     $C0FD88

	ORG $C0FFA2					; WaitForCD
	jsr     LoadCDSectorFromSD
	rts
	ORG $C0FFE6					; WaitForNewSector (useless now ?)
	jsr     LoadCDSectorFromSD
	rts
	ORG $C1002A					; WaitForCD2
	jsr     LoadCDSectorFromSD
	rts
	ORG $C10134					; WaitForLoaded
	jsr     LoadCDSectorFromSD
	rts

	ORG $C10206
    jmp     LoadFromCD			; Patch original "LoadFromCD" (multiple calls)

	ORG $C11774
	lea     $100040,a6        	; Disable CD player display and erase finger cursor from splash screen
	move.b  #0,4(a6)			; Sprite height
	bra     $C16CF2				; "SpriteUpdateVRAM"


	; New code starts from here ---------------------------

	ORG $C19000
PUPPETStuff:
	move.w  #0,($FF0000).l		; Copied from original routine, required for PUPPET init
	move.w  #$550,($FF0002).l
    move.w  #$731,($FF0004).l
    move.b  #$FE,($FF0011).l
    move.b  #$3C,($FF000E).l
	move.w  #7,(REG_IRQACK).l
	andi.w  #$F8FF,sr
	
	move.w  #$0000,FixWriteConfig

	jsr     InitSD              ; Added
	rts

	
DrawProgressAnimation:
    lea     FixValueList,a0
    moveq.l #0,d0
	move.w  $10F688,d0			; "SectorCounter"
	move.l  d0,(a0)
    lea     FixStrSector,a0
	move.w  #FIXMAP+16+(18*32),d0
    jsr     WriteFix 			; Display sector counter
	rts


LoadFile:
	move.w  #$3100,FixWriteConfig

    lea     FixStrClear,a0
	move.w  #FIXMAP+16+(4*32),d0
    jsr     WriteFix 			; Clear file name line

    movea.l $10F6A0,a0			; "FilenamePtr"
	move.w  #FIXMAP+16+(4*32),d0
    jsr     WriteFix 			; Display filename

	moveq.l #0,d0				; Copied from original routine
    move.b  $10F6C2,d0			; "FileTypeCode"
    lsl.b   #2,d0
    lea     $C0F60A,a0			; "JTFileLoaders"
    movea.l 0(a0,d0),a0
    jmp     (a0)


BCDtoHex:
    andi.l  #$FF,d0
    move.b  d0,d1
    lsr.b   #4,d0
    andi.b  #$F,d1
    mulu.w  #10,d0
    add.b   d1,d0
    rts


CDCheckDone:
	;lea     $1113C2,a1			; "CDSectorBuffer" + 0x1BE (first partition entry)
	btst   	#7,$10F656			; "CDValidFlag"
	bne     .valid
	lea     $111204,a1			; Dump memory starting from "CDSectorBuffer" and lock up
	bra     DumpMemory
.valid:
	clr.b   $10F6B6				; Original code "CDLoadBusy"
	bclr    #0,$7656(a5)		; Original code "CDValidFlag"
	jmp     $C0EE4E				; Return to original code


LoadFromCD:
    movem.l d0-d7/a0-a6,-(sp)	; LoadFromCD jump patch

	move.b  d0,REG_DIPSW
	lea     PALETTES,a0
	move.w  #BLACK,(a0)+		; Set up palettes for text
	move.w  #WHITE,(a0)+
	move.w  #BLACK,(a0)
	
	move.b  #1,REG_ENVIDEO
	move.b  #0,REG_DISBLSPR
	move.b  #0,REG_DISBLFIX

    lea     FixValueList,a0
	move.l  $10F6C8,d0			; Retrieve requested MSF
	lsr.l   #8,d0
	move.l  d0,(a0)
    lea     FixStrReqSec,a0
	move.w  #FIXMAP+6+(6*32),d0
	jsr     WriteFix            ; Display requested MSF
	move.b  d0,REG_DIPSW

	lea     $10F6C8,a0			; Convert MSF to LBA in iso file
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
	subi.l  #150,d3				; Remove 2 second gap
	lsl.l   #8,d3				; Absolute hex address (CD sector = 2048 bytes)
	lsl.l   #3,d3
	move.l  d3,ISOLoadStart
	move.b  d0,REG_DIPSW

    lea     FixValueList,a0
	move.l  d3,(a0)
    lea     FixStrIsoAddr,a0
	move.w  #FIXMAP+7+(6*32),d0
	jsr     WriteFix            ; Display address in ISO file
	move.b  d0,REG_DIPSW

	moveq.l #0,d0
	move.w  $10F688,d0			; Retrieve requested sector count to load
	move.w  d0,CDSectorCount	; Make our own copy, just in case
    lea     FixValueList,a0
	move.l  d0,(a0)
    lea     FixStrCDSecCnt,a0
	move.w  #FIXMAP+8+(6*32),d0
	jsr     WriteFix            ; Display number of sectors to load
	move.b  d0,REG_DIPSW

	move.l  #$411000,SDISOStart	; Hardcoded for now DEBUG (10000 Partition start + 401000 FAT end)

	move.l  SDISOStart,d0
	add.l   ISOLoadStart,d0
	move.l  d0,SDLoadStart

    lea     FixValueList,a0
	move.l  d0,(a0)
    lea     FixStrSDAddr,a0
	move.w  #FIXMAP+9+(6*32),d0
	jsr     WriteFix            ; Display absolute address of loading start in SD card
	move.b  d0,REG_DIPSW

	moveq.l #0,d0
	move.w  CDSectorCount,d0
	lsl.l   #2,d0
	move.l  d0,SDSectorCount	; CD sector = 2048 bytes = 4 SD sectors = 4 * 512 bytes

    lea     FixValueList,a0
	move.l  d0,(a0)
    lea     FixStrSDSecCnt,a0
	move.w  #FIXMAP+10+(6*32),d0
	jsr     WriteFix            ; Display absolute address of loading start in SD card
	move.b  d0,REG_DIPSW

    movem.l (sp)+,d0-d7/a0-a6

	rts

    INCLUDE "exceptions.asm"
	INCLUDE "print.asm"
	INCLUDE "sdcard.asm"
	INCLUDE "fat32.asm"
	INCLUDE "strings.asm"

	ORG $C20C10   				; Replace palette #3 during loading screen (for debug text)
	dc.w BLACK, WHITE, BLACK

	ORG $C6DEB0
	BINCLUDE "fix_alphabet_bank.bin"

    ORG $C6FEB0
	BINCLUDE "sprites.bin"
