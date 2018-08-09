WriteFix:
	move.b  d0,REG_DIPSW
    movem.l d2-d7/a1,-(sp)
	move.w  FixWriteConfig,d1
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
    movem.l (sp)+,d2-d7/a1
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
    lea     FixValueList,a1
    move.l  (a1,d3),d3
	move.w  d1,d2
    moveq.l #8,d7
.writelong:
	rol.l   #4,d3
	move.b  d3,d2
	andi.b  #$F,d2
	cmpi.b  #9,d2
	bls     .deci
    addi.b  #7,d2
.deci:
    addi.b  #$30,d2
	move.w  d2,REG_VRAMRW
	subq.b  #1,d7
	bne     .writelong
    bra     .write
    
    
ClearFix:
	move.w  #$7000,REG_VRAMADDR
	nop
	move.w  #1,REG_VRAMMOD
	move.w  #32*40,d7
.clear:
    move.w  #$0020,REG_VRAMRW
	move.b  d0,REG_DIPSW
	subq.w  #1,d7
	bne     .clear
	rts
	

RefreshDump:
	jsr     ClearFix

	move.w  #$3100,FixWriteConfig	; Palette 3, bank 1
	
	; Print address
	lea     FixValueList,a0
	move.l  a1,(a0)+
    lea     FixStrViewAddr,a0
	move.w  #FIXMAP+3+(2*32),d0
	jsr     WriteFix

	movea.l a1,a2
	move.w  #32,REG_VRAMMOD
    move.w  #FIXMAP+5+(6*32),d0
	move.w  #24,d7			; 24 lines
.writeblock:
	move.w  d0,REG_VRAMADDR
	moveq.l #0,d1
	move.w  #16,d6			; 16 bytes per line (32 chars)
.writeline:
	move.b  d0,REG_DIPSW
	move.b  (a2)+,d2		; Read byte from memory
	move.b  d2,d1 			; Split in nibbles

	lsr.b   #4,d1
	cmpi.b  #9,d1
	bls     .deci_a			; Hexify
    addi.b  #7,d1
.deci_a:
    addi.b  #$30,d1
	or.w    FixWriteConfig,d1
	move.w  d1,REG_VRAMRW
	
	move.b  d2,d1
	andi.b  #$F,d1
	cmpi.b  #9,d1
	bls     .deci_b			; Hexify
    addi.b  #7,d1
.deci_b:
    addi.b  #$30,d1
	move.w  d1,REG_VRAMRW

	subq.b  #1,d6
	bne     .writeline

	addi.w  #1,d0			; Go down one line in the fix map
	subq.b  #1,d7
	bne     .writeblock
	rts


MemoryViewer:
	move.b  d0,REG_DIPSW

	lea     (2*16*3)+PALETTES,a0	; Set up palette 3 for text
	move.w  #BLACK,(a0)+
	move.w  #WHITE,(a0)+
	move.w  #BLACK,(a0)

	jsr     RefreshDump

	move.b  #1,REG_ENVIDEO
	move.b  #0,REG_DISBLSPR
	move.b  #0,REG_DISBLFIX

.loop:
	move.b  d0,REG_DIPSW

	move.b  BIOS_P1CHANGE,d0

    cmp.b   #$01,d0
    bne     .no_up
	;cmp.l   #0,a1
	;beq     .no_up
	subi.l  #16,a1				; UP: Address -= 16
	jsr     RefreshDump
.no_up:
    cmp.b   #$02,d0
    bne     .no_down
	addi.l  #16,a1				; DOWN: Address += 16
	jsr     RefreshDump
.no_down:
    cmp.b   #$04,d0
    bne     .no_left
	subi.l  #256,a1				; LEFT: Address -= 256
	jsr     RefreshDump
.no_left:
    cmp.b   #$08,d0
    bne     .no_right
	addi.l  #256,a1				; RIGHT: Address += 256
	jsr     RefreshDump
.no_right:

    bra     .loop
