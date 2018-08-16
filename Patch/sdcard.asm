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
;Write byte, wait while busy sending (only during low clk speed ?)
;
;12MHz / 30 = 375kHz for slow SPI ?
;Is 12MHz safe for fast SPI ?

InitSD:
    move.w  SDREG_UNLOCK,d0

    ; 80 pulses with DOUT = 1
	move.b  #10,d7
.clks:
	move.w  #$02FF,d0			; CS high, low speed, data all ones
	jsr     PutByteSPI
	subq.b  #1,d7
	bne     .clks

	; Make card go to idle state
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
	move.l  #0,d2				; No parameter
	jsr     SDCommand
	jsr     GetR1				; Ignore
	move.w  #$0029,d0			; CS low, low speed, ACMD41
	move.l  #0,d2				; No parameter	$40000000 ?
	jsr     SDCommand
	jsr     GetR1
	move.w  #0,d5				; Default card type: MMC
	cmp.b   #$01,d0
	bhi     .mmc
	move.w  #1,d5				; SDC card !
.mmc:
	move.w  d5,CardType

	move.w  CardType,d5
    move.b  #200,d7				; Max tries
.init:
	jsr     Delay
	tst.b   d5
	beq     .mmc_init
	move.w  #$0037,d0			; CS low, low speed, CMD55
	move.l  #0,d2				; No parameter
	jsr     SDCommand
	jsr     GetR1				; Ignore
	move.w  #$0029,d0			; CS low, low speed, ACMD41
	move.l  #0,d2				; No parameter	$40000000 ?
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

	; Stop any previous multiple-read
	; TODO: Probably not necessary to try multiple times
	move.w  #$010C,d0			; CS low, high speed, CMD12
	moveq.l #0,d2
	jsr     SDCommand
	moveq.l #200,d6				; Max tries
.trystop:
	move.b  d0,REG_DIPSW
	move.w  #$01FF,d0			; CS low, high speed, data all ones
	jsr     PutByteSPI
	cmp.b   #$FF,d0
	beq     .notbusy
	subq.b  #1,d6
	bne     .trystop
	moveq.l #6,d0				; CMD12 failed
	jmp		ErrSD
.notbusy:

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
	moveq.l #10,d6				; Max tries
.try:
	move.b  d0,REG_DIPSW
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

; Uses D1, D2, D4, A0
SDCommand:
    move.w  d0,d1
	move.w  #$00FF,d0           ; Just clock pulses with CS low
	jsr     PutByteSPI
    move.w  d1,d0

	ori.b   #64,d0				; Command byte
	jsr     PutByteSPI

	rol.l   #8,d2               ; Parameter AAAAAAAA BBBBBBBB CCCCCCCC DDDDDDDD
    move.w  d1,d0
	move.b  d2,d0               ;           BBBBBBBB CCCCCCCC DDDDDDDD AAAAAAAA
	jsr     PutByteSPI
	rol.l   #8,d2				;           CCCCCCCC DDDDDDDD AAAAAAAA BBBBBBBB
    move.w  d1,d0
	move.b  d2,d0
	jsr     PutByteSPI
	rol.l   #8,d2				;           DDDDDDDD AAAAAAAA BBBBBBBB CCCCCCCC
    move.w  d1,d0
	move.b  d2,d0
	jsr     PutByteSPI
	rol.l   #8,d2				;           AAAAAAAA BBBBBBBB CCCCCCCC DDDDDDDD
    move.w  d1,d0
	move.b  d2,d0
	jsr     PutByteSPI

	tst.b   d1
	beq     .crc_cmd0
	cmp.b   #$08,d1
	beq     .crc_cmd8
	move.w  #$00FF,d0			; Ignored CRC
.cmd_ret:
	jsr     PutByteSPI

	move.w  #$00FF,d0			; Just clock pulses
	jsr     PutByteSPI
	rts
	
.crc_cmd0:
	move.w  #$0095,d0			; CMD0's CRC
	bra     .cmd_ret
.crc_cmd8:
	move.w  #$0087,d0			; CMD8's CRC
	bra     .cmd_ret


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
	
	
; Uses d0,d4,a0
PutByteSPIFast:
    move.w  SDREG_CSLOW,d4          ; 16

	movea.l #SDREG_DOUTBASE,a0		; 12
	add.w   d0,d0                   ; 4
	andi.w  #$1FE,d0                ; TESTING: Was .l Seems ok
	adda.w  d0,a0                   ; TESTING: Was .l Seems ok
    move.w  (a0),d4                 ; 8

	; Wait for interface not busy
	move.w  #$FFFF,d4				; 8
.wait:
	;move.b  d0,REG_DIPSW            ; 16
	move.w  SDREG_STATUS,d0         ; 16
	andi.b  #1,d0                   ; 8
	beq     .done                   ; 10/8
	nop                             ; 4
	subq.w  #1,d4                   ; 4
	bne     .wait                   ; 10/8
	moveq.l #0,d0					; SPI interface timeout
	jmp		ErrSD
.done:

	move.b  SDREG_DIN,d0            ; 16
	rts


; Uses D0, D6, A0, A1
; Uses A1
LoadSDSector:
	move.b  d0,REG_DIPSW

    move.w  SDREG_HIGHSPEED,d0
    move.w  SDREG_CSLOW,d0

	lea     SDREG_DIN_WORD,a0

	move.w  SDREG_INITBURST,d0	; Start burst read

	; TESTING:
	; NOPs aren't related to DRAM write speed
	move.w  #16,d6 			; Read whole SD sector in words (512 bytes) 512/32=16
.readsector:
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	move.w  (a0),(a1)+		; SPI word read
	nop
	subq.w  #1,d6
	bne     .readsector

	move.b  d0,REG_DIPSW
	rts


; MAKE SURE THIS PRESERVES USED REGISTERS !
; Uses d0,d4,d6,d7,a0,a1
LoadRawSectorFromSD:
    movem.l d0-d7/a0-a1,-(sp)	; SLOW!

	; Start new multiple-read
	move.w  #$0111,d0			; CS low, high speed, CMD17 (17 = $11)
	move.l  SDLoadStart,d2
	jsr     SDCommand
	jsr     GetR1
	tst.b   d0
	beq     .cmdreadok
	moveq.l #7,d0				; CMD17 wasn't accepted
	jmp		ErrSD
.cmdreadok:

	lea     SDSectorBuffer,a1

	; Wait for data token
	move.l  #20000,d6			; Max tries
.try:
	move.b  d0,REG_DIPSW
	move.w  #$01FF,d0			; CS low, high speed, data all ones
	jsr     PutByteSPIFast
	cmp.b   #$FE,d0
	beq     .gottoken
	subq.l  #1,d6
	bne     .try
	moveq.l #5,d0				; Didn't get the data token in time
	jmp		ErrSD
.gottoken:

	jsr     LoadSDSector

	move.w  #$01FF,d0			; Discard CRC
	jsr     PutByteSPIFast
	move.w  #$01FF,d0
	jsr     PutByteSPIFast

	move.w  #$0300,d0			; CS high
	jsr     PutByteSPI

    movem.l (sp)+,d0-d7/a0-a1	; SLOW!
    rts


; MAKE SURE THIS PRESERVES USED REGISTERS !
; Uses d0,d4,d6,d7,a0,a1
LoadCDSectorFromSD:
    movem.l d0-d7/a0-a1,-(sp)	; SLOW!
	move.b  d0,REG_DIPSW

	moveq.l #4,d7               ; 4 SD sectors = 1 CD sector, 2048/512=4
	lea     $111204,a1			; "CDSectorBuffer"

.readsectors:

	; Wait for data token
	move.l  #20000,d6			; Max tries
.try:
	move.b  d0,REG_DIPSW
	move.w  #$01FF,d0			; CS low, high speed, data all ones
	jsr     PutByteSPIFast
	cmp.b   #$FE,d0
	beq     .gottoken
	subq.l  #1,d6
	bne     .try
	moveq.l #5,d0				; Didn't get the data token in time
	jmp		ErrSD
.gottoken:

	jsr     LoadSDSector

	move.w  #$01FF,d0			; Discard CRC
	jsr     PutByteSPIFast
	move.w  #$01FF,d0
	jsr     PutByteSPIFast

	move.w  #$0300,d0			; CS high
	jsr     PutByteSPI

	addi.l  #512,SDLoadStart

	subq.b  #1,d7
	tst.b   d7
	bne     .readsectors

	; DEBUG
;	move.b  d0,REG_DIPSW
;	move.b  BIOS_P1CURRENT,d0	; Stall and go to memory viewer on C+D press during loading
;    cmp.b   #$C0,d0
;	bne     .go_on
;	lea     $0,a1				; Dump memory starting from $000000 and lock up
;	jmp     MemoryViewer
;.go_on:

	;lea     FixValueList,a0		; SLOW! Used only for debug
	;move.l  SDLoadStart,(a0)+
    ;lea     FixStrCurAddr,a0
	;move.w  #FIXMAP+12+(6*32),d0
	;jsr     WriteFix            ; Display absolute address of loading start in SD card and Subsector (3~0)

	; For original progressbar update:
	;move.b  d0,REG_DIPSW
	move.l  $10F690,d0
	add.l   $10F68C,d0
	cmpi.l  #$800000,d0
	bls     .nocap
	move.l  #$800000,d0
.nocap:
	move.l  d0,$10F690

    subq.w  #1,CDSectorCount
	move.w  CDSectorCount,$10F688

    movem.l (sp)+,d0-d7/a0-a1	; SLOW!
    rts
