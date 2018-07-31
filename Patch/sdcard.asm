;SD card notes:
;
;CMD0, arg $00000000, CRC $95. Response should be $01
;CMD8, arg $000001AA, CRC $87. Response should be $01 followed by arg echo
;CMD55, arg $00000000, CRC xx. Response should be $01, or $05 for old cards: goto CMD1
;ACMD41, arg $40000000, CRC xx. Response should be $00
;(CMD1, arg ...)
;
;Init sequence:
;
;Set SPI speed to slow
;DI & CS high, >74 clks
;CS low, CMD0 -> Idle state (R1 = $01)
;CMD55?
;ACMD41?
;CMD1 for old cards ? -> Read until R1 = $00 or timeout (>100ms !)
;Set SPI speed to fast
;CMD16 to set block length
;
;Data packet:
;
;CMD17, arg block number: Single block read
;Read until token ($FE) is received
;Receive 512 bytes + 2 bytes CRC
;
;Interface:
;
;We need a speed switch for clk (<=400kHz -> X MHz)
;Write byte, wait while busy sending (only during low clk speed ?)
;
;12MHz / 32 = 375kHz for slow SPI ?
;Is 12MHz safe for fast SPI ?
;
; "Writes" are done by reading at specific addresses

InitSD:
	jsr     UnlockSD

	move.b  #10,d7				; 80 pulses with DOUT = 1
.clks:
	move.w  #$02FF,d0			; CS high, low speed, data all ones
	jsr     PutByteSPI
	subq.b  #1,d7
	bne     .clks

    move.b  #50,d7				; Max tries
.cmd0:
	move.w  #$0000,d0			; CS low, low speed, CMD0
	move.l  #0,d2				; No parameter
	jsr     SDCommand
	jsr     GetR1
	cmp.b   #$01,d0				; Idle state ?
	beq     .ok0
	jsr     Delay
	subq.b  #1,d7
	bne     .cmd0
	moveq.l #1,d0				; CMD0 failed
	jmp		ErrSD
.ok0:

	move.w  #$0037,d0			; CS low, low speed, CMD55
	jsr     SDCommand
	move.w  #$0029,d0			; CS low, low speed, ACMD41
	jsr     SDCommand
	jsr     GetR1
	move.b  #0,d5				; Default card type: MMC
	cmp.b   #$01,d0
	bhi     .mmc
	move.b  #1,d5				; SDC card !
.mmc:

    move.b  #200,d7				; Max tries
.init:
	jsr     Delay
	tst.b   d5
	beq     .mmc_init
	move.w  #$0037,d0			; CS low, low speed, CMD55
	jsr     SDCommand
	move.w  #$0029,d0			; CS low, low speed, ACMD41
	jsr     SDCommand
	bra     .sdc_init
.mmc_init:
	move.w  #$0001,d0			; CS low, low speed, CMD1
	jsr     SDCommand
.sdc_init:
	jsr     GetR1
	tst.b   d0
	beq     .initok
	subq.b  #1,d7
	bne     .init
	moveq.l #2,d0				; Error step 2: Init failed
	jmp		ErrSD
.initok:

	move.w  #$000D,d0			; CS low, low speed, CMD13
	jsr     SDCommand
	jsr     GetR2
	tst.w   d0
	beq     .statok
	moveq.l #3,d0				; Error step 3: Wrong card status
	jmp		ErrSD
.statok:

	move.w  #$0010,d0			; CS low, low speed, CMD16
	move.l  #512,d2
	jsr     SDCommand
	jsr     GetR1
	tst.b   d0
	beq     .blocklenok
	moveq.l #4,d0				; Error step 4: Can't set block length
	jmp		ErrSD
.blocklenok:

	; We can go full speed now
	move.w  #$0200,d0			; CS high
	jsr     PutByteSPI
	rts


Delay:
	move.b  d0,REG_DIPSW
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    rts

; Uses D6
GetR1:
	move.b  d0,REG_DIPSW
	moveq.l #10,d6				; Max tries
.try:
	move.w  #$00FF,d0			; CS low, low speed, data all ones
	jsr     PutByteSPI
	cmp.b   #$FF,d0
	bne     .gotr1
	subq.b  #1,d6
	bne     .try
.gotr1:
    rts

GetR2:
	move.b  d0,REG_DIPSW
    jsr     GetR1
    lsl.w   #8,d0
    move.w  d0,d1
	move.w  #$00FF,d0			; CS low, low speed, data all ones
	jsr     PutByteSPI
	move.b  d0,d1
	move.w  d1,d0
	rts

	moveq.l #10,d6				; Max tries
.try:
	move.w  #$00FF,d0			; CS low, low speed, data all ones
	jsr     PutByteSPI
	cmp.b   #$FF,d0
	bne     .gotr1
	subq.b  #1,d6
	bne     .try
.gotr1:
    rts

; Uses D1, D2, D4, A0
SDCommand:
    move.w  d0,d1
	move.w  #$00FF,d0           ; Just clock pulses with CS low
	jsr     PutByteSPI
    move.w  d1,d0

	ori.b   #64,d0				; Command byte
	jsr     PutByteSPI

	rol.l   #8,d2               ; Parameter AAAAAAAA BBBBBBBB CCCCCCCC DDDDDDDD
	move.b  d2,d0               ;           BBBBBBBB CCCCCCCC DDDDDDDD AAAAAAAA
	jsr     PutByteSPI
	rol.l   #8,d2				;           CCCCCCCC DDDDDDDD AAAAAAAA BBBBBBBB
	move.b  d2,d0
	jsr     PutByteSPI
	rol.l   #8,d2				;           DDDDDDDD AAAAAAAA BBBBBBBB CCCCCCCC
	move.b  d2,d0
	jsr     PutByteSPI
	rol.l   #8,d2				;           AAAAAAAA BBBBBBBB CCCCCCCC DDDDDDDD
	move.b  d2,d0
	jsr     PutByteSPI

	move.w  #$00FF,d0			; Ignored CRC
	tst.b   d1
	bne     .not_cmd0
	move.w  #$0095,d0			; CMD0's CRC (slow)
.not_cmd0:
	jsr     PutByteSPI

	move.w  #$00FF,d0			; Just clock pulses
	jsr     PutByteSPI
	rts


PutByteSPI:
	move.b  d0,REG_DIPSW

	; SLOW! Do only once with a separate routine ?
	movea.l #SDREG_HIGHSPEED,a0		; 12
	btst.l  #8,d0                   ; 10
    bne     .fast                   ; 10/8
	movea.l #SDREG_LOWSPEED,a0
.fast:
    move.w  (a0),d4                 ; 8

	movea.l #SDREG_CSHIGH,a0		; 12
	btst.l  #9,d0                   ; 10
    bne     .cs_high             	; 10/8
	movea.l #SDREG_CSLOW,a0
.cs_high:
    move.w  (a0),d4                 ; 8

	movea.l #SDREG_DOUTBASE,a0		; 12
	add.w   d0,d0                   ; 4
	andi.l  #$1FE,d0                ; 16
	adda.l  d0,a0                   ; 8
    move.w  (a0),d4                 ; 8

	; Wait for interface not busy
	move.w  #$FFFF,d4				; 8
.wait:
	move.w  SDREG_STATUS,d0         ; 8
	btst.l  #0,d0                   ; 10
	beq     .done                   ; 10/8
	move.b  d0,REG_DIPSW            ; 16
	nop                             ; 4
	subq.w  #1,d4                   ; 4
	bne     .wait                   ; 10/8
	moveq.l #0,d0					; SPI interface timeout
	jmp		ErrSD
.done:

	move.b  SDREG_DIN,d0            ; 8
	rts
	
	
PutByteSPIFast:
	move.b  d0,REG_DIPSW

    move.w  SDREG_CSLOW,d4

	movea.l #SDREG_DOUTBASE,a0		; 12
	add.w   d0,d0                   ; 4
	andi.w  #$1FE,d0                ; TESTING: Was .l Seems ok
	adda.w  d0,a0                   ; TESTING: Was .l Seems ok
    move.w  (a0),d4                 ; 8

	; Wait for interface not busy
	move.w  #$FFFF,d4				; 8
.wait:
	move.w  SDREG_STATUS,d0         ; 8
	btst.l  #0,d0                   ; 10
	beq     .done                   ; 10/8
	move.b  d0,REG_DIPSW            ; 16
	nop                             ; 4
	subq.w  #1,d4                   ; 4
	bne     .wait                   ; 10/8
	moveq.l #0,d0					; SPI interface timeout
	jmp		ErrSD
.done:

	move.b  SDREG_DIN,d0            ; 8
	rts


ErrSD:
	lea     PALETTES,a0			; Set up palettes for text
	move.w  #BLACK,(a0)+
	move.w  #WHITE,(a0)+
	move.w  #BLACK,(a0)

	jsr     ClearFix

	move.b  #1,REG_ENVIDEO
	move.b  #0,REG_DISBLSPR
	move.b  #0,REG_DISBLFIX

    lea     ErrFixStrList,a0
	add.w   d0,d0
	adda.l  d0,a0
	movea.l (a0),a0
	move.w  #FIXMAP+4+(4*32),d0
	jsr     WriteFix
.lockup:
	move.b  d0,REG_DIPSW
	nop
	nop
	nop
    bra     .lockup

LockSD:
    move.w  SDREG_LOCK,d0
	rts

UnlockSD:
    move.w  SDREG_UNLOCK,d0
    rts
