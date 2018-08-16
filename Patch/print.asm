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
    
    
WriteWord:
	move.w  FixWriteConfig,d1
	move.w  #32,REG_VRAMMOD
    nop
    nop
    nop
    move.w  d0,REG_VRAMADDR
    moveq.l #4,d7
.writeword:
	rol.w   #4,d2
	move.b  d2,d3
	andi.b  #$F,d3
	cmpi.b  #9,d3
	bls     .deci
    addq.b  #7,d3
.deci:
    addi.b  #$30,d3
	move.w  d3,REG_VRAMRW
	subq.b  #1,d7
	bne     .writeword
	rts


DrawISOList:
    ; Erase previous list
	move.w  #32,REG_VRAMMOD
	move.w  #FIXMAP+9+(10*32),d0
	move.w  #16,d7
.cl_line:
	move.w  d0,REG_VRAMADDR
	move.w  #18,d6
.cl_char:
	move.w  #$3020,REG_VRAMRW	; Space, palette 3
	nop
	subq.b  #1,d6
	bne     .cl_char
	addi.w  #1,d0				; Next line
	subq.b  #1,d7
	bne     .cl_line

	; Display ISO file names (and their first cluster index)
	moveq.l #16,d7				; Max lines on screen
	lea     ISOFilesList,a1
	moveq.l #0,d0
	move.b  MenuShift,d0
	lsl.l   #4,d0				; *16
	adda.l  d0,a1
	move.w  #FIXMAP+9+(10*32),d2
.disp:
	tst.b   (a1)
	beq     .disp_done
	movea.l a1,a0
	move.w  d2,d0
	jsr     WriteFix

	move.l  12(a1),d0			; Get first cluster index
    lea     FixValueList,a0
	move.l  d0,(a0)
	move.w  d2,d0
	addi.w  #9*32,d0			; Move right
    lea     FixStrClusterIdx,a0
	jsr     WriteFix
	
	subq.b  #1,d7
	beq     .disp_done			; Max lines

	addi.w  #1,d2				; Next line
    lea     16(a1),a1			; Next entry
	bra     .disp
.disp_done:

	clr.b   RefreshList
	rts
