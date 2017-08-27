ErrBus:
    move.l  10(a7),PCERROR      ; Store PC from stack frame
    movem.l d0-d7/a0-a6,-(a7)   ; Store registers
    lea     FixStrErrBus,a0
    jmp     DispExc

ErrAddr:
    move.l  10(a7),PCERROR      ; Store PC from stack frame
    movem.l d0-d7/a0-a6,-(a7)   ; Store registers
    lea     FixStrErrAddr,a0
    jmp     DispExc
    
ErrIllegal:
    move.l  2(a7),PCERROR       ; Store PC from stack frame
    movem.l d0-d7/a0-a6,-(a7)   ; Store registers
    lea     FixStrErrIllegal,a0
    jmp     DispExc

ErrGeneric:
    move.l  2(a7),PCERROR       ; Store PC from stack frame
    movem.l d0-d7/a0-a6,-(a7)   ; Store registers
    lea     FixStrErrGeneric,a0
    jmp     DispExc

ErrUninit:
    move.l  2(a7),PCERROR       ; Store PC from stack frame
    movem.l d0-d7/a0-a6,-(a7)   ; Store registers
    lea     FixStrErrUninit,a0
    jmp     DispExc
    

DispExc:
	ori.w   #$0700,sr

	move.w  #FIXMAP+8+(4*32),d0
	jsr     WriteFix

    lea     FixStrOhCrap,a0
	move.w  #FIXMAP+5+(4*32),d0
	jsr     WriteFix

	;subi.l  #60,a7				; Rewind stack pointer
    lea     FixValueList,a0
    move.b  #8,d7
.loadDRegs:
	move.l  (a7)+,(a0)+
	subq.b  #1,d7
	bne     .loadDRegs
    lea     FixStrDRegsDump,a0
	move.w  #FIXMAP+9+(4*32),d0
	jsr     WriteFix

    lea     FixValueList,a0
    move.b  #7,d7
.loadARegs:
	move.l  (a7)+,(a0)+
	subq.b  #1,d7
	bne     .loadARegs
	move.l  PCERROR,(a0)
    lea     FixStrARegsDump,a0
	move.w  #FIXMAP+9+(16*32),d0
	jsr     WriteFix

	lea     PALETTES,a0			; Set up palettes for text
	move.w  #BLACK,(a0)+
	move.w  #RED,(a0)+
	move.w  #BLACK,(a0)

	move.b  #1,REG_ENVIDEO
	move.b  #0,REG_DISBLSPR
	move.b  #0,REG_DISBLFIX

.lockup:
	move.b  d0,REG_DIPSW
	nop
	nop
	nop
    bra     .lockup
