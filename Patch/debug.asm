DrawProgressAnimation:
	; Display sector counter at 18,16
	move.w  #$3100,FixWriteConfig
	move.w  #FIXMAP+16+(20*32),d0
	move.w  $10F688,d2			; "SectorCounter"
    jsr     WriteWord
	;lea     FixValueList,a0
    ;moveq.l #0,d0
	;move.w  $10F688,d0			; "SectorCounter"
	;move.l  d0,(a0)
    ;lea     FixStrSector,a0
	;move.w  #FIXMAP+16+(20*32),d0
    ;jsr     WriteFix
	rts
	
DebugDispFileName:
	move.w  #$3100,FixWriteConfig

    lea     FixStrClear,a0
	move.w  #FIXMAP+16+(4*32),d0
    jsr     WriteFix 			; Clear file name line

    movea.l $10F6A0,a0			; "FilenamePtr"
	move.w  #FIXMAP+16+(4*32),d0
    jsr     WriteFix 			; Display filename
    rts
    
DebugDispMSF:
    ; Display requested MSF at 6,3
    lea     FixValueList,a0
	move.l  $10F6C8,d0			; Retrieve requested MSF
	lsr.l   #8,d0               ; Rightmost byte is unused
	move.l  d0,(a0)
    lea     FixStrReqSec,a0
	move.w  #FIXMAP+3+(6*32),d0
	jsr     WriteFix
	move.b  d0,REG_DIPSW
	rts
	
DebugDispISOAddr:
    ; Display address in ISO file at 6,4
    lea     FixValueList,a0
	move.l  d3,(a0)
    lea     FixStrIsoAddr,a0
	move.w  #FIXMAP+4+(6*32),d0
	jsr     WriteFix
	move.b  d0,REG_DIPSW
	rts
	
DebugDispCDSectors:
    ; Display number of CD sectors to load at 6,5
	moveq.l #0,d0
	move.w  $10F688,d0			; Retrieve requested sector count to load
    lea     FixValueList,a0
	move.l  d0,(a0)
    lea     FixStrCDSecCnt,a0
	move.w  #FIXMAP+5+(6*32),d0
	jsr     WriteFix
	move.b  d0,REG_DIPSW
	rts
	
DebugDispSDAddr:
    ; Display absolute address of loading start in SD card at 6,6
    lea     FixValueList,a0
	move.l  d0,(a0)
    lea     FixStrSDAddr,a0
	move.w  #FIXMAP+6+(6*32),d0
	jsr     WriteFix
	move.b  d0,REG_DIPSW
	rts


RefreshDump:
	jsr     ClearFix

	move.w  #$3000,FixWriteConfig	; Palette 3, bank 0
	
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
	jsr     Hexify
	or.w    FixWriteConfig,d1
	move.w  d1,REG_VRAMRW
	
	move.b  d2,d1
	andi.b  #$F,d1
	jsr     Hexify
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
