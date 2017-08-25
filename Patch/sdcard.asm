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
; "Writes" are done by reading at specific addresses:
; Lock: $C04652 or $C04653
; Unlock: $C046A0 or $C046A1
; Write byte: $C04400~$C04401 to $C045FE~$C045FF (shift left once)
; Read byte: $C04800 or $C04801
; CS: $C04600 or $C04601 for 0, $C04610 or $C04611 for 1
; Speed:  $C04700 or $C04701 for SLOW, $C04710 or $C04711 for FAST
; Status: Read $C04900 or $C04901

InitSD:
	jsr     UnlockSD

	move.b  #10,d7				; 80 pulses with DOUT = 1
.clks:
	move.w  #$03FF,d0			; CS high, low speed, data all ones
	jsr     PutByteSPI
	subq.b  #1,d7
	bne     .clks

    move.b  #50,d7				; Max tries
.cmd0:
	move.w  #$0100,d0			; CS low, low speed, CMD0
	move.l  #0,d2				; No parameter
	jsr     SDCommand
	jsr     GetR1
	cmp.b   #$01,d0				; Idle state ?
	beq     .ok0
	jsr     Delay
	subq.b  #1,d7
	bne     .cmd0
	moveq.l #1,d0				; Error step 1: CMD0 failed
	jmp		Error
.ok0:

	move.w  #$0137,d0			; CS low, low speed, CMD55
	jsr     SDCommand
	move.w  #$0129,d0			; CS low, low speed, ACMD41
	jsr     SDCommand
	jsr     GetR1
	move.b  #0,d5				; Default card type: MMC
	cmp.b   #$01,d0
	bhi     .mmc
	move.b  #1,d5				; SDC card !
.mmc:

    move.b  #50,d7				; Max tries
.init:
	jsr     Delay
	tst.b   d1
	beq     .mmc_init
	move.w  #$0137,d0			; CS low, low speed, CMD55
	jsr     SDCommand
	move.w  #$0129,d0			; CS low, low speed, ACMD41
	jsr     SDCommand
	bra     .sdc_init
.mmc_init:
	move.w  #$0101,d0			; CS low, low speed, CMD1
	jsr     SDCommand
.sdc_init:
	jsr     GetR1
	tst.b   d0
	beq     .initok
	subq.b  #1,d7
	bne     .init
	moveq.l #2,d0				; Error step 2: Init failed
	jmp		Error
.initok:

	move.w  #$010D,d0			; CS low, low speed, CMD13
	jsr     SDCommand
	jsr     GetR2
	tst.w   d0
	beq     .statok
	moveq.l #3,d0				; Error step 3: Wrong card status
	jmp		Error
.statok:

	move.w  #$0110,d0			; CS low, low speed, CMD16
	move.l  #512,d2
	jsr     SDCommand
	jsr     GetR1
	tst.b   d0
	beq     .blocklenok
	moveq.l #4,d0				; Error step 4: Can't set block length
	jmp		Error
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
    
GetR1:
	move.b  d0,REG_DIPSW
	moveq.l #10,d6				; Max tries
.try:
	move.w  #$01FF,d0			; CS low, low speed, data all ones
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
	move.w  #$01FF,d0			; CS low, low speed, data all ones
	jsr     PutByteSPI
	move.b  d0,d1
	move.w  d1,d0
	rts

	moveq.l #10,d6				; Max tries
.try:
	move.w  #$01FF,d0			; CS low, low speed, data all ones
	jsr     PutByteSPI
	cmp.b   #$FF,d0
	bne     .gotr1
	subq.b  #1,d6
	bne     .try
.gotr1:
    rts

SDCommand:
    move.w  d0,d1
	move.w  #$01FF,d0			; Just clock pulses
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

	move.w  #$01FF,d0			; Ignored CRC
	tst.b   d1
	bne     .not_cmd0
	move.w  #$0195,d0			; CMD0's CRC
.not_cmd0:
	jsr     PutByteSPI
	
	move.w  #$01FF,d0			; Just clock pulses
	jsr     PutByteSPI
	rts


PutByteSPI:
	move.b  d0,REG_DIPSW

	movea.l #$C04710,a0
	btst.l  #8,d0
    beq     .fast
	movea.l #$C04700,a0
.fast:
    move.w  (a0),d4
    
	movea.l #$C04610,a0
	btst.l  #9,d0
    bne     .cs_high
	movea.l #$C04600,a0
.cs_high:
    move.w  (a0),d4

	movea.l #$C04400,a0
	lsl.w   #1,d0
	andi.l  #$1FE,d0
	adda.l  d0,a0
    move.w  (a0),d4

	move.l  #$1FFFF,d4
.wait:
	move.b  d0,REG_DIPSW
	nop
	move.w  $C04900,d0
	btst.l  #0,d0
	beq     .done
	subq.l  #1,d4
	bne     .wait
	moveq.l #9,d0				; Error 9: SPI timeout
	jmp		Error
.done:

	move.b  $C04800,d0
	rts

Error:
	lea     PALETTES,a0			; Set up palettes for text
	move.w  #BLACK,(a0)+
	move.w  #WHITE,(a0)+
	move.w  #BLACK,(a0)
	
	move.b  #1,REG_ENVIDEO
	move.b  #0,REG_DISBLSPR
	move.b  #0,REG_DISBLFIX

    lea     FixValueList,a0
	move.l  d0,(a0)
    lea     FixStrSDError,a0
	move.w  #FIXMAP+4+(4*32),d0
	jsr     WriteFix
.lockup:
	move.b  d0,REG_DIPSW
	nop
	nop
	nop
    bra     .lockup
    
FixStrSDError:
    dc.b    "SD CARD ERR ",$F0,0

LockSD:
    move.w  $C04652,d0
	rts

UnlockSD:
    move.w  $C046A0,d0
    rts
