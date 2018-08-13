BCDtoHex:
    andi.l  #$FF,d0
    move.b  d0,d1
    lsr.b   #4,d0
    andi.b  #$F,d1
    mulu.w  #10,d0
    add.b   d1,d0
    rts
    
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
	
Hexify:
	cmpi.b  #9,d1
	bls     .deci
    addi.b  #7,d1
.deci:
    addi.b  #$30,d1
    rts

CompareStrings:
	tst.b   (a1)
	beq     .done
	cmpm.b  (a0)+,(a1)+
	beq     CompareStrings
.done:
    rts
