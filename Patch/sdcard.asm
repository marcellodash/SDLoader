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
;Magic bytes to unlock SD access: $741C
;Magic bytes to lock SD access: $57F1
;
;Writes to system ROM space ? Can we catch /WR ?
;$C00000: Lock/unlock (write only)
;$C00002: SD byte write. LSByte = data, MSByte = flags
;		Flags: bit8 = send byte
;       	   bit9 = CS state
;			   bit15 = high speed
;$C80000: SD byte read (LSByte)

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
	move.w  #$0140,d0			; CS low, low speed, CMD0
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
	
	moveq.l #5,d0				; Error step 5: Not an error, success !
	jmp		Error
	rts
	

Delay:
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

	move.b  d2,d0				; Parameter (little-endian)
	jsr     PutByteSPI
	lsr.l   #8,d2
	move.b  d2,d0
	jsr     PutByteSPI
	lsr.l   #8,d2
	move.b  d2,d0
	jsr     PutByteSPI
	lsr.l   #8,d2
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
	move.w  d0,$C00002
.wait:
	nop
	move.w  $C80000,d0
	btst.l  #8,d0
	bne     .wait
	rts
	
Error:
    lea     FixValueList,a0
	move.l  d0,(a0)
    lea     FixStrSDError,a0
	move.w  #FIXMAP+4+(4*32),d0
	move.w  #$0000,d1
	jsr     WriteFix
    rts
    
FixStrSDError:
    dc.b    "SD CARD ERR ",$F0,0

LockSD:
    move.w  #$57F1,$C00000
	rts

UnlockSD:
    move.w  #$741C,$C00000
    rts
