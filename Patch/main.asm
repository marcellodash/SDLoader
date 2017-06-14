    cpu 68000
    supmode on
    INCLUDE "regdefs.asm"

	INCLUDE "splash.asm"

FixValueList	equ		$10E000	; OK ?


    ORG $C0C854
	jmp     PUPPETStuff			; Called at startup

	ORG $C11774
	lea     $100040,a6        	; Disable CD player display and erase finger from splash screen
	move.b  #0,4(a6)			; Sprite height
	bra     $C16CF2				; SpriteUpdateVRAM

	ORG $C0EBC8
	nop							; Disable "WAIT..." message
	nop

	ORG $C0EBF2
	nop							; Disable "WAIT..." message (again)
	nop

	;ORG $C10206
    ;jmp     LoadFromCD			; Patch original LoadFromCD (multiple calls)

	ORG $C0F5FC
	jmp     LoadFile			; Patch original LoadFile
	
	ORG $C0F324
	bra     $C0F348				; Prevent loading custom loading screens
	ORG $C0F382
	bra     $C0F3AA             ; Same
	ORG $C0EDA2
	bra     $C0EE00             ; Same
	
	ORG $C0E712
	jmp     DrawProgressAnimation	; Don't draw loading progress animation

	ORG $C19000
PUPPETStuff:
	move.w  #0,($FF0000).l		; Copied from original routine, required for PUPPET init
	move.w  #$550,($FF0002).l
    move.w  #$731,($FF0004).l
    move.b  #$FE,($FF0011).l
    move.b  #$3C,($FF000E).l
	move.w  #7,(REG_IRQACK).l
	andi.w  #$F8FF,sr

	;jsr     InitSD
	rts

;$00: End of string
;$01: Move from origin X, Y
;$Fx: Print stored longword
FixStrSecReq:
    dc.b "LOAD MMSSFF ",$F0,0
FixStrSecHex:
    dc.b "ISO ADDRESS ",$F0,0
FixStrSecCount:
	dc.b "SECTORS CNT ",$F0,0

FixStrClear:
    dc.b "            ",0
FixStrSector:
	dc.b "SEC ",$F0,0
	
	
DrawProgressAnimation:
    lea     FixValueList,a0
    moveq.l #0,d0
	move.w  $10F688,d0			; Sector counter
	move.l  d0,(a0)
	
    lea     FixStrSector,a0
	move.w  #FIXMAP+16+(18*32),d0
    move.w  #$3100,d1
    jsr     WriteFix 			; Display sector counter
	rts


LoadFile:
    lea     FixStrClear,a0
	move.w  #FIXMAP+16+(4*32),d0
    move.w  #$3100,d1
    jsr     WriteFix 			; Clear file name line

    movea.l $76A0(a5),a0
	move.w  #FIXMAP+16+(4*32),d0
    move.w  #$3100,d1
    jsr     WriteFix 			; Display filename

	moveq.l #0,d0				; Copied from original routine
    move.b  $76C2(a5),d0
    lsl.b   #2,d0
    lea     $C0F60A,a0
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


LoadFromCD:
	jsr     InitSD 				; Todo: PUT BACK IN PUPPETStuff !

	lea     PALETTES,a0			; LoadFromCD jump patch
	move.w  #BLACK,(a0)+		; Set up palettes for text
	move.w  #WHITE,(a0)+
	move.w  #BLACK,(a0)

    lea     FixValueList,a0
	move.l  $10F6C8,d0			; MSF
	lsr.l   #8,d0
	move.l  d0,(a0)
    lea     FixStrSecReq,a0
	move.w  #FIXMAP+6+(6*32),d0
	move.w  #$0000,d1
	jsr     WriteFix            ; Display requested MSF

	lea     $10F6C8,a0			; MSF
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
	lsl.l   #8,d3				; Absolute hex address
	lsl.l   #3,d3

    lea     FixValueList,a0
	move.l  d3,(a0)
    lea     FixStrSecHex,a0
	move.w  #FIXMAP+7+(6*32),d0
	move.w  #$0000,d1
	jsr     WriteFix            ; Display address for ISO file

	moveq.l #0,d0
	move.w  $10F688,d0
    lea     FixValueList,a0
	move.l  d0,(a0)
    lea     FixStrSecCount,a0
	move.w  #FIXMAP+8+(6*32),d0
	move.w  #$0000,d1
	jsr     WriteFix            ; Display number of sectors to load

.lp
	bra     .lp

	INCLUDE "print.asm"
	INCLUDE "sdcard.asm"

	ORG $C20C10   				; Palette #3 during loading screen
	dc.w BLACK, WHITE, BLACK

	ORG $C6DEB0
	BINCLUDE "fix_alphabet_bank.bin"

    ORG $C6FEB0
	BINCLUDE "sprites.bin"
