    cpu 68000
    supmode on
    INCLUDE "regdefs.asm"

	INCLUDE "splash.asm"
	
FixValueList	equ		$10E000	; OK ?


	
	ORG $C0E7C0
	nop							; Disable CD player display
	nop
	
	ORG $C0EBC8
	nop							; Disable "WAIT..." message
	nop

	ORG $C0EBF2
	nop							; Disable "WAIT..." message
	nop

	ORG $C10206
    jmp     LoadFromCD

	
	
	ORG $C19000
WriteFix:
    move.w  #32,REG_VRAMMOD
    nop
    nop
    nop
    move.w  d0,REG_VRAMADDR
.write:
    move.b  (a0)+,d1
    tst.b   d1
    beq     .strend
    cmp.b   #1,d1
	beq     .reloc
    cmpi.b  #$F0,d1
    bhs     .value
	move.w  d1,REG_VRAMRW
    bra     .write
.strend:
	rts
	
.reloc:
    moveq.l #0,d3
    move.b  (a0)+,d3
    lsl.w   #5,d3
    add.w   d0,d3
    add.b   (a0)+,d3
    move.w  d3,REG_VRAMADDR
    bra     .write


.value:
    moveq.l #0,d3
    move.b  d1,d3
    andi.b  #7,d3
    lsl.w   #2,d3
    lea     FixValueList,a0
    move.l  (a0,d3),d3
	move.w  d1,d2
    move.l  #8,d7
.writelong:
	rol.l   #4,d3
	move.b  d3,d2
	andi.b  #$F,d2
	cmpi.b  #9,d2
	bls     .deci
    addi.b  #$11,d2
.deci:
    addi.b  #$30,d2
	move.w  d2,REG_VRAMRW
	subq.b  #1,d7
	bne     .writelong
    bra     .write


FixStrSecReq:
    dc.b "LOAD --MMSSFF",1,5,1,$F0,0
FixStrSecHex:
    dc.b "ISO ADDRESS",1,5,1,$F0,0

BCDtoHex:
    andi.l  #$FF,d0
    move.b  d0,d1
    lsr.b   #4,d0
    andi.b  #$F,d1
    mulu.w  #10,d0
    add.b   d1,d0
    rts

    
LoadFromCD:
	lea     PALETTES,a0			; LoadFromCD jump patch
	move.w  #BLACK,(a0)+
	move.w  #WHITE,(a0)+
	move.w  #BLACK,(a0)

    lea     FixValueList,a0
	move.l  $10F6C8,d0			; MSF
	lsr.l   #8,d0
	move.l  d0,(a0)
    lea     FixStrSecReq,a0
	move.w  #FIXMAP+6+(6*32),d0
	move.w  #$0000,d1
	jsr     WriteFix

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
	move.w  #FIXMAP+8+(6*32),d0
	move.w  #$0000,d1
	jsr     WriteFix

.lp
	bra     .lp


    ORG $C6FEB0
	BINCLUDE "sprites.bin"
