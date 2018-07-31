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
    move.l  #8,d7
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
	move.l  #32*40,d7
.clear:
    move.w  #$0020,REG_VRAMRW
	move.b  d0,REG_DIPSW
	subq.l  #1,d7
	bne     .clear
	rts
    

DumpMemory:
	move.b  d0,REG_DIPSW
	lea     PALETTES,a0			; Set up palettes for text
	move.w  #BLACK,(a0)+
	move.w  #WHITE,(a0)+
	move.w  #BLACK,(a0)

	jsr     ClearFix
	
	move.b  #1,REG_ENVIDEO
	move.b  #0,REG_DISBLSPR
	move.b  #0,REG_DISBLFIX

	move.w  #$3100,FixWriteConfig

	move.w  #32,REG_VRAMMOD
    nop
    nop
    nop
    move.w  #FIXMAP+2+(2*32),d0
	move.l  #26,d7
.writeblock:
	move.w  d0,REG_VRAMADDR
	moveq.l #0,d1
	move.l  #18,d6
.writeline:
	move.b  d0,REG_DIPSW
	move.b  (a1)+,d2

	move.b  d2,d1
	lsr.b   #4,d1
	cmpi.b  #9,d1
	bls     .deci_a
    addi.b  #7,d1
.deci_a:
    addi.b  #$30,d1
	or.w    FixWriteConfig,d1
	move.w  d1,REG_VRAMRW
	
	move.b  d2,d1
	andi.b  #$F,d1
	cmpi.b  #9,d1
	bls     .deci_b
    addi.b  #7,d1
.deci_b:
    addi.b  #$30,d1
	move.w  d1,REG_VRAMRW

	subq.b  #1,d6
	bne     .writeline

	addi.w  #1,d0
	subq.b  #1,d7
	bne     .writeblock

.lockup:
	move.b  d0,REG_DIPSW
	nop
	nop
	nop

	move.b  BIOS_P1CURRENT,d0	; A=0 B=512 C=512+512 D=512+512+512

    cmp.b   #$10,d0
    bne     .no_a
	lea     $111204,a1			; Dump memory starting from "CDSectorBuffer" and lock up
	bra     DumpMemory
.no_a:
    cmp.b   #$20,d0
    bne     .no_b
	lea     $111404,a1			; Dump memory starting from "CDSectorBuffer" and lock up
	bra     DumpMemory
.no_b:
    cmp.b   #$40,d0
    bne     .no_c
	lea     $111604,a1			; Dump memory starting from "CDSectorBuffer" and lock up
	bra     DumpMemory
.no_c:
    cmp.b   #$80,d0
    bne     .no_d
	lea     $111804,a1			; Dump memory starting from "CDSectorBuffer" and lock up
	bra     DumpMemory
.no_d:

    bra     .lockup
