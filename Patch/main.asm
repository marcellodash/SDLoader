    cpu 68000
    supmode on
    INCLUDE "regdefs.asm"
	INCLUDE "equ.asm"

    INCLUDE "vectors.asm"

	INCLUDE "splash.asm"

	; CURRENT STATUS:
	; Loading of files seem to work correctly, PRG files -ARE- loaded correctly
	; League Bowling loads and starts correctly, but gets stuck during attract mode after the ball zooms in
	; The game select screen is animated but the countdown timer doesn't work, no reaction to controls
	; Probably patched BIOS call issue

	; AOF3 loads but either resets or loads infinitely

	; TRIED:
	; Replace League Bowling's .PRG by a custom one that just changes the backdrop color and sits in a loop
	; kicking the watchdog. Backdrop color is set according to the VBL vector value (see if it's correct or not).
	; Use a button to enable/disable interrupts. When game starts, SR should be == $2700 (all disabled).
	; Result: works perfectly. VBL vector is correct. Enabling/disabling interrupts with SR also works perfectly.

	; Disabling CDC IRQs doesn't change anything


	; STUFF FOR WHEN GAMES WILL WORK:
	; Todo: Do longword reads instead of bytes
	; Once a SD sector read is started, put FPGA in x-longwords read mode for 512 bytes

	; From MAME's m68kops.cpp:
	; move.b #addr,(a0)+:		20 cycles for 1 byte	Yield: 0.05 bytes per cycle
	; move.b (a0),(a1)+:		12 cycles for 1 bytes   Yield: 0.08
	; move.w (a0),(a1)+:		12 cycles for 2 bytes   Yield: 0.16 TESTING THIS
	; move.l (a0),(a1)+:		20 cycles for 4 bytes   Yield: 0.2  TO TRY ?

	; PROGRESS LOG:
	
	; The IPL loading for TEST.ISO (League Bowling) is 5 files, total 2511536 bytes
	; With SD sector loading 8*bytes with 2x NOPs
	; Time taken: 2511536 bytes / 20.4s = 123114 bytes/s = 120kbytes/s
	; Scope for PRG files: 13.8ms for 2048 bytes (1 CD sector): 145kbytes/s
	;	SD sectors read, 2048 bytes: 4.31ms							31% :(
	;		One SD sector read, 512 bytes: 4.31/4=1.07ms
	;		Actual burst read for 512 bytes: 920us: 543kbytes/s		85% :)
	;		Read setup for 512 bytes: 159us	                        15% :)
	;	CD sector processing time: 9.6ms							69% :(
	; CD sector processing is too slow !
	
	; With debug checksumming removed, and SD sector loading 8*bytes with 1x NOPs
	; Time taken: 2511536 bytes / 9.2s = 272993 bytes/s = 266.6kbytes/s
	; Scope for PRG files: 5.32ms for 2048 bytes (1 CD sector): 376kbytes/s
	;	SD sectors read, 2048 bytes: 3.64ms							68% :)
	;		One SD sector read, 512 bytes: 3.64/4=910us
	;		Actual burst read for 512 bytes: 752us: 665kbytes/s		83% :)
	;		Read setup for 512 bytes: 158us	                        17%
	;	CD sector processing time: 1.68ms							32%
	; Scope for SPR files: 5.44ms for 2048 bytes (1 CD sector): 368kbytes/s
	;	SD sectors read, 2048 bytes: 3.66ms							67%
	;	CD sector processing time: ?ms								33%

	; With PutByteSPIFast, some debug print removed, SPI signalling optimized and removed nops for byte loads
	; -> Crashes
	; With PutByteSPIFast, some debug print removed, SPI signalling optimized
	; -> Loads OK, ~9s total
	; PCM sector processing is slower than the rest :(
	
	; With 16bit SPI burst reads and CPU word reads:
	; ...

	; When AOF3 was working:
	; The IPL loading for TEST.ISO (Art of Fighting 3) is 13 files, total 1909814 bytes
	; Time taken: 1909814 bytes / 10.08s = 189527 bytes/s = 185kbytes/s
	; Scope for PRG files: 8.44ms for 2048 bytes (1 CD sector): 237kbytes/s
	;	SD sectors read, 2048 bytes: 6.8ms							80%
	;		One SD sector read, 512 bytes: 6.8/4=1.7ms
	;		Actual burst read for 512 bytes: 1.008ms: 496kbytes/s	62%
	;		Read setup for 512 bytes: 0.581ms                       38% :(
	;	CD sector processing time: 1.764ms							20% :(
	; Gain from 1x CD speed: (185-150)/150 = 23%

	; With SD multiple read command, set-up each CD sector: 7.38ms for 2048 bytes (1 CD sector): 271kbytes/s
	; Time taken: 1909814 bytes / 8.74s = 218462 bytes/s = 213kbytes/s
	; Gain from 1x CD speed: (213-150)/150 = 42%
	; Gain from previous step: (213-185)/185 = 15%

	; With SD multiple read command, set-up each new file:
	; Time taken: 1909814 bytes / 7.51s = 254404 bytes/s = 248kbytes/s
	; Gain from 1x CD speed: (248-150)/150 = 65%
	; Gain from previous step: (248-213)/213 = 16%

	; With SD multiple read command, set-up each new file, byte-to-word copy optimization:
	; Time taken: 1909814 bytes / 6.94s = 275178 bytes/s = 268kbytes/s
	; Gain from 1x CD speed: (248-150)/150 = 78%
	; Gain from previous step: (268-248)/248 = 8%

	; Patches ---------------------------

	; Not doing this freezes just before loading IPL
	ORG $C0C360					; Removes CD-related calls in SYSTEM_INT1
	nop			; Not NOPing this causes the freeze because CDReadyFlag is reset somewhere
	nop
	;nop      	; Testing (doesn't change)
	;nop
	;nop		; Testing: Let InitCDComm go (doesn't change)
	;nop

	; TODO: Re-enable this when loading will work !
	;ORG $C0BF5E
	;jmp     CopyBytesToWordCPULoop	; Cache-to-DRAM copy speed optimization attempt

    ORG $C0C854
	jmp     PUPPETStuff			; Insertion - Called at startup
	
    ORG $C0CBD2
	nop							; Bypass CD lid check in SYSTEM_IO
	nop

	ORG $C0E712
	jmp     DrawProgressAnimation	; Insertion - Loading progress animation

	ORG $C0E8D2
	bra    $C0E968             	; Skip CD player interface updating, just go to rts

	ORG $C0EBA2
	nop                         ; Disable CD mech detection in CheckCDValid
	nop                         ; Overwrite up to movem.l ...
	nop
	nop
	nop
	nop

	ORG $C0EBC8
	nop							; Disable "WAIT A MOMENT" message
	nop

	ORG $C0EBF2
	nop							; Disable "WAIT A MOMENT" message (again)
	nop

	;REMOVED FOR TESTING
	;ORG $C0EE58
	;rts							; Disable SetCDDMode as a whole

	ORG $C0EC16
	jsr     LoadCDSectorFromSD	; Load first sector (CD001...)
	move.b  d0,REG_DIPSW
	bra     $C0EC3A				; Skip first sector loading wait, there's no more CD :)

	ORG $C0EDA2
	bra     $C0EE00             ; Prevent loading LOGO files (custom loading screens)

	ORG $C0EE04
	nop							; Bypass CD lid check

    ORG $C0EE0C
	jmp     CDCheckDone         ; Insertion - Used to trigger a memory dump in case the "CD" isn't validated

	ORG $C0EF4C                 ; "GetCDFileList"
	tst.w   $10F688				; "SectorCounter"
	beq     $C0EFD0				; No more sectors to load: go to rts
	jsr     LoadCDSectorFromSD
	bra     $C0EF66

	ORG $C0EF6C					; Bypass CD lid check
	nop
	nop
	nop

	ORG $C0F022					; Disable waiting for CD Op to be processed
	rts

	ORG $C0F4E8					; Disable waiting for CD to stop after BIOSF_LOADFILE
	nop
	nop

	ORG $C0F324
	bra     $C0F348				; Prevent loading custom loading screens
	ORG $C0F382
	bra     $C0F3AA             ; Same

	ORG $C0F5FC
	jmp     LoadFile			; Patch original LoadFile

	ORG $C0FD78
	jsr     LoadCDSectorFromSD	; Load sector in SearchForFile
	bra     $C0FD88				; Skip waiting

	ORG $C0FFA2					; WaitForCD
	jsr     LoadCDSectorFromSD
	rts

	ORG $C0FFE6					; WaitForNewSector (useless now ?)
	jsr     LoadCDSectorFromSD
	rts

	ORG $C1002A					; WaitForCD2
	jsr     LoadCDSectorFromSD
	rts

	ORG $C10134					; WaitForLoaded
	jsr     LoadCDSectorFromSD
	rts

	ORG $C10206
    jmp     LoadFromCD			; Patch original "LoadFromCD" (multiple calls)

	ORG $C11774
	;jsr     $C0B278			; Todo: Just jump to ClearSprites ?
	lea     $100040,a6        	; Disable CD player display and erase finger cursor from splash screen
	move.b  #0,4(a6)			; Sprite height
	bra     $C16CF2				; "SpriteUpdateVRAM"
	
	ORG $C167FE
	moveq.l #1,d0
	move.b  d0,$764E(a5)
	move.b  d0,$7656(a5)		; Init "CDValidFlag" to 1 instead of 0 to kickstart CD checking


	; New code starts from here ---------------------------

	ORG $C19000
PUPPETStuff:
	move.w  #0,($FF0000).l		; Copied from original routine OK, required for PUPPET init
	move.w  #$550,($FF0002).l
    move.w  #$731,($FF0004).l
    move.b  #$FE,($FF0011).l
    move.b  #$3C,($FF000E).l
	move.w  #7,(REG_IRQACK).l
	andi.w  #$F8FF,sr

	move.w  #$0000,FixWriteConfig 	; Added

	jsr     InitSD                  ; Added
	rts
    

DrawProgressAnimation:
    lea     FixValueList,a0
    moveq.l #0,d0
	move.w  $10F688,d0			; "SectorCounter"
	move.l  d0,(a0)
    lea     FixStrSector,a0
	move.w  #FIXMAP+16+(18*32),d0
    jsr     WriteFix 			; Display sector counter
	rts


LoadFile:
	move.w  #$3100,FixWriteConfig

    lea     FixStrClear,a0
	move.w  #FIXMAP+16+(4*32),d0
    jsr     WriteFix 			; Clear file name line

    movea.l $10F6A0,a0			; "FilenamePtr"
	move.w  #FIXMAP+16+(4*32),d0
    jsr     WriteFix 			; Display filename

	moveq.l #0,d0				; Copied from original routine
    move.b  $10F6C2,d0			; "FileTypeCode"
    lsl.b   #2,d0
    lea     $C0F60A,a0			; "JTFileLoaders"
    movea.l 0(a0,d0),a0
    jmp     (a0)


BCDtoHex:
    andi.l  #$FF,d0
    move.b  d0,d1
    lsr.b   #4,d0
    andi.b  #$F,d1
    mulu.w  #10,d0
    add.b   d1,d0
    rts


CDCheckDone:
	;lea     $1113C2,a1			; "CDSectorBuffer" + 0x1BE (first partition entry)
	btst   	#7,$10F656			; "CDValidFlag"
	bne     .valid
	lea     $111204,a1			; Dump memory starting from "CDSectorBuffer" and lock up
	bra     DumpMemory
.valid:
	clr.b   $10F6B6				; Original code "CDLoadBusy"
	bclr    #0,$7656(a5)		; Original code "CDValidFlag"
	jmp     $C0EE4E				; Return to original code


LoadFromCD:
    movem.l d0-d7/a0-a6,-(sp)	; LoadFromCD jump patch
    
    ; TESTING: Copied from original code
    move.b  #1,$76B6(a5)
    clr.b   $76B7(a5)
    ;Ignore PushCDOp
	move.w  #4,$7684(a5)
	move.b  #64,$76BA(a5)
	move.b  #64,$76BB(a5)
	clr.w   $76BC(a5)
	move.w  #$550,$FF0002
	move.b  #1,$FF0101
	move.b  #%11100010,$FF0103
	move.b  #$A,$FF0101
	move.b  #%10100111,$FF0103
	move.b  #%11110000,$FF0103


	move.b  d0,REG_DIPSW
	lea     PALETTES,a0
	move.w  #BLACK,(a0)+		; Set up palettes for text
	move.w  #WHITE,(a0)+
	move.w  #BLACK,(a0)
	
	move.b  #1,REG_ENVIDEO
	move.b  #0,REG_DISBLSPR
	move.b  #0,REG_DISBLFIX

    lea     FixValueList,a0
	move.l  $10F6C8,d0			; Retrieve requested MSF
	lsr.l   #8,d0               ; Rightmost byte is unused
	move.l  d0,(a0)
    lea     FixStrReqSec,a0
	move.w  #FIXMAP+6+(6*32),d0
	jsr     WriteFix            ; Display requested MSF
	move.b  d0,REG_DIPSW

	lea     $10F6C8,a0			; Convert MSF to LBA in iso file
	moveq.l #0,d3
	move.b  (a0)+,d0			; M
	jsr     BCDtoHex
	mulu.w  #75*60,d0
	add.l   d0,d3
	move.b  (a0)+,d0			; S
	jsr     BCDtoHex
	mulu.w  #75,d0
	add.l   d0,d3
	move.b  (a0)+,d0			; F
	jsr     BCDtoHex
	add.l   d0,d3
	subi.l  #2*75,d3			; Remove 2 second gap
	lsl.l   #8,d3				; Absolute hex address in ISO file (CD sector = 2048 bytes)
	lsl.l   #3,d3
	move.l  d3,ISOLoadStart
	move.b  d0,REG_DIPSW

    lea     FixValueList,a0
	move.l  d3,(a0)
    lea     FixStrIsoAddr,a0
	move.w  #FIXMAP+7+(6*32),d0
	jsr     WriteFix            ; Display address in ISO file
	move.b  d0,REG_DIPSW

	moveq.l #0,d0
	move.w  $10F688,d0			; Retrieve requested sector count to load
	move.w  d0,CDSectorCount	; Make our own copy, just in case
    lea     FixValueList,a0
	move.l  d0,(a0)
    lea     FixStrCDSecCnt,a0
	move.w  #FIXMAP+8+(6*32),d0
	jsr     WriteFix            ; Display number of sectors to load
	move.b  d0,REG_DIPSW

	; Partition start is longword at 0x1C * sector size ? ex: 0x81*0x0200 = 10200
	move.l  #$411200,SDISOStart	; Hardcoded for now DEBUG (10200 Partition start + 401000 FAT end)

	move.l  SDISOStart,d0
	add.l   ISOLoadStart,d0
	move.l  d0,SDLoadStart

    lea     FixValueList,a0
	move.l  d0,(a0)
    lea     FixStrSDAddr,a0
	move.w  #FIXMAP+9+(6*32),d0
	jsr     WriteFix            ; Display absolute address of loading start in SD card
	move.b  d0,REG_DIPSW

	moveq.l #0,d0
	move.w  CDSectorCount,d0
	;lsl.l   #2,d0
	;move.l  d0,SDSectorCount	; CD sector = 2048 bytes = 4 SD sectors = 4 * 512 bytes

    lea     FixValueList,a0
	move.l  d0,(a0)
    lea     FixStrSDSecCnt,a0
	move.w  #FIXMAP+10+(6*32),d0
	jsr     WriteFix            ; Display total number of SD sectors to load
	move.b  d0,REG_DIPSW
	
	; Stop eventual previous multiple-read
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

	; Start new multiple-read
	move.w  #$0112,d0			; CS low, high speed, CMD18 (18 = $12)
	move.l  SDLoadStart,d2
	jsr     SDCommand
	jsr     GetR1
	tst.b   d0
	beq     .cmdreadok
	moveq.l #7,d0				; CMD18 wasn't accepted
	jmp		ErrSD
.cmdreadok:

	move.w  #0,DebugChecksumIdx

    movem.l (sp)+,d0-d7/a0-a6

	rts

; TODO: Check first if the copy size is a multiple of 8 !
CopyBytesToWordCPULoop:
	move.b  (a0)+,d0
    move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
    move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
    move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
    move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	subq.l  #8,d7
	bne.s   CopyBytesToWordCPULoop

	rts

    INCLUDE "exceptions.asm"
	INCLUDE "print.asm"
	INCLUDE "sdcard.asm"
	INCLUDE "fat32.asm"
	INCLUDE "strings.asm"

	padding on

debug_filename:
    dc.b "PROG_CD.PRG"

debug_checksums:
	dc.w $777E ; 000000~0007FF
	dc.w $A58E ; 000800~000FFF
	dc.w $C1CE ; 001000~0017FF
	dc.w $C310 ; 001800~001FFF
	dc.w $D464 ; 002000~0027FF
	dc.w $A877 ; 002800~002FFF
	dc.w $A98F ; 003000~0037FF
	dc.w $6FAA ; 003800~003FFF
	dc.w $A0A1 ; 004000~0047FF
	dc.w $C67F ; 004800~004FFF
	dc.w $8148 ; 005000~0057FF
	dc.w $4FAE ; 005800~005FFF
	dc.w $CBE2 ; 006000~0067FF
	dc.w $0E27 ; 006800~006FFF
	dc.w $1E83 ; 007000~0077FF
	dc.w $8CF8 ; 007800~007FFF
	dc.w $7E42 ; 008000~0087FF
	dc.w $5215 ; 008800~008FFF
	dc.w $B4FE ; 009000~0097FF
	dc.w $2C23 ; 009800~009FFF
	dc.w $F512 ; 00A000~00A7FF
	dc.w $F0DE ; 00A800~00AFFF
	dc.w $8B9E ; 00B000~00B7FF
	dc.w $C2CD ; 00B800~00BFFF
	dc.w $7F0D ; 00C000~00C7FF
	dc.w $9C20 ; 00C800~00CFFF
	dc.w $5E9A ; 00D000~00D7FF
	dc.w $18D1 ; 00D800~00DFFF
	dc.w $CDED ; 00E000~00E7FF
	dc.w $B193 ; 00E800~00EFFF
	dc.w $30EF ; 00F000~00F7FF
	dc.w $1B5F ; 00F800~00FFFF
	dc.w $0412 ; 010000~0107FF
	dc.w $5E65 ; 010800~010FFF
	dc.w $1607 ; 011000~0117FF
	dc.w $12DC ; 011800~011FFF
	dc.w $21BA ; 012000~0127FF
	dc.w $09A0 ; 012800~012FFF
	dc.w $029D ; 013000~0137FF
	dc.w $0A9F ; 013800~013FFF
	dc.w $67B6 ; 014000~0147FF
	dc.w $0E71 ; 014800~014FFF
	dc.w $C25C ; 015000~0157FF
	dc.w $D59C ; 015800~015FFF
	dc.w $4796 ; 016000~0167FF
	dc.w $86B1 ; 016800~016FFF
	dc.w $4F9A ; 017000~0177FF
	dc.w $650D ; 017800~017FFF
	dc.w $8FB5 ; 018000~0187FF
	dc.w $5AF0 ; 018800~018FFF
	dc.w $55B9 ; 019000~0197FF
	dc.w $6F5C ; 019800~019FFF
	dc.w $A9BB ; 01A000~01A7FF
	dc.w $6663 ; 01A800~01AFFF
	dc.w $6E3F ; 01B000~01B7FF
	dc.w $A419 ; 01B800~01BFFF
	dc.w $938F ; 01C000~01C7FF
	dc.w $0934 ; 01C800~01CFFF
	dc.w $D78B ; 01D000~01D7FF
	dc.w $711C ; 01D800~01DFFF
	dc.w $7AA7 ; 01E000~01E7FF
	dc.w $84AA ; 01E800~01EFFF
	dc.w $2E23 ; 01F000~01F7FF
	dc.w $8E5F ; 01F800~01FFFF
	dc.w $69A5 ; 020000~0207FF
	dc.w $2F20 ; 020800~020FFF
	dc.w $9F47 ; 021000~0217FF
	dc.w $A88D ; 021800~021FFF
	dc.w $9580 ; 022000~0227FF
	dc.w $AB05 ; 022800~022FFF
	dc.w $AE12 ; 023000~0237FF
	dc.w $B78E ; 023800~023FFF
	dc.w $D537 ; 024000~0247FF
	dc.w $B851 ; 024800~024FFF
	dc.w $5F93 ; 025000~0257FF
	dc.w $5188 ; 025800~025FFF
	dc.w $5AF3 ; 026000~0267FF
	dc.w $6ED2 ; 026800~026FFF
	dc.w $4C02 ; 027000~0277FF
	dc.w $667A ; 027800~027FFF
	dc.w $1C1C ; 028000~0287FF
	dc.w $513A ; 028800~028FFF
	dc.w $5541 ; 029000~0297FF
	dc.w $2B3D ; 029800~029FFF
	dc.w $9338 ; 02A000~02A7FF
	dc.w $77B9 ; 02A800~02AFFF
	dc.w $A031 ; 02B000~02B7FF
	dc.w $0788 ; 02B800~02BFFF
	dc.w $224D ; 02C000~02C7FF
	dc.w $1814 ; 02C800~02CFFF
	dc.w $FDDB ; 02D000~02D7FF
	dc.w $DC5A ; 02D800~02DFFF
	dc.w $0606 ; 02E000~02E7FF
	dc.w $2A83 ; 02E800~02EFFF
	dc.w $142E ; 02F000~02F7FF
	dc.w $36CC ; 02F800~02FFFF
	dc.w $34C9 ; 030000~0307FF
	dc.w $52C7 ; 030800~030FFF
	dc.w $F465 ; 031000~0317FF
	dc.w $330E ; 031800~031FFF
	dc.w $2488 ; 032000~0327FF
	dc.w $4082 ; 032800~032FFF
	dc.w $CD1D ; 033000~0337FF
	dc.w $B3BD ; 033800~033FFF
	dc.w $9C08 ; 034000~0347FF
	dc.w $E161 ; 034800~034FFF
	dc.w $5E1B ; 035000~0357FF
	dc.w $5931 ; 035800~035FFF
	dc.w $7833 ; 036000~0367FF
	dc.w $186F ; 036800~036FFF
	dc.w $0441 ; 037000~0377FF
	dc.w $7CC4 ; 037800~037FFF
	dc.w $A8E7 ; 038000~0387FF
	dc.w $6179 ; 038800~038FFF
	dc.w $5D10 ; 039000~0397FF
	dc.w $ADEC ; 039800~039FFF
	dc.w $8124 ; 03A000~03A7FF
	dc.w $5278 ; 03A800~03AFFF
	dc.w $848C ; 03B000~03B7FF
	dc.w $9A42 ; 03B800~03BFFF
	dc.w $BBB9 ; 03C000~03C7FF
	dc.w $5940 ; 03C800~03CFFF
	dc.w $9A33 ; 03D000~03D7FF
	dc.w $5C59 ; 03D800~03DFFF
	dc.w $4723 ; 03E000~03E7FF
	dc.w $8A3F ; 03E800~03EFFF
	dc.w $A58D ; 03F000~03F7FF
	dc.w $91BB ; 03F800~03FFFF
	dc.w $A5FA ; 040000~0407FF
	dc.w $84FC ; 040800~040FFF
	dc.w $6ED0 ; 041000~0417FF
	dc.w $8D16 ; 041800~041FFF
	dc.w $4FED ; 042000~0427FF
	dc.w $59CE ; 042800~042FFF
	dc.w $5B11 ; 043000~0437FF
	dc.w $B6C2 ; 043800~043FFF
	dc.w $AE47 ; 044000~0447FF
	dc.w $259B ; 044800~044FFF
	dc.w $7636 ; 045000~0457FF
	dc.w $B513 ; 045800~045FFF
	dc.w $F32D ; 046000~0467FF
	dc.w $D142 ; 046800~046FFF
	dc.w $F80A ; 047000~0477FF
	dc.w $DBFB ; 047800~047FFF
	dc.w $C7F2 ; 048000~0487FF
	dc.w $AFB9 ; 048800~048FFF
	dc.w $0C21 ; 049000~0497FF
	dc.w $FCCC ; 049800~049FFF
	dc.w $CE52 ; 04A000~04A7FF
	dc.w $A7F5 ; 04A800~04AFFF
	dc.w $DC0A ; 04B000~04B7FF
	dc.w $C253 ; 04B800~04BFFF
	dc.w $D17F ; 04C000~04C7FF
	dc.w $702C ; 04C800~04CFFF
	dc.w $7A9C ; 04D000~04D7FF
	dc.w $B47C ; 04D800~04DFFF
	dc.w $4E8D ; 04E000~04E7FF
	dc.w $C36E ; 04E800~04EFFF
	dc.w $A519 ; 04F000~04F7FF
	dc.w $8A8B ; 04F800~04FFFF
	dc.w $A1D5 ; 050000~0507FF
	dc.w $2BA2 ; 050800~050FFF
	dc.w $C061 ; 051000~0517FF
	dc.w $1AF8 ; 051800~051FFF
	dc.w $10AD ; 052000~0527FF
	dc.w $1015 ; 052800~052FFF
	dc.w $06F6 ; 053000~0537FF
	dc.w $7791 ; 053800~053FFF
	dc.w $E724 ; 054000~0547FF
	dc.w $4B1E ; 054800~054FFF
	dc.w $6963 ; 055000~0557FF
	dc.w $CF46 ; 055800~055FFF
	dc.w $1BBB ; 056000~0567FF
	dc.w $042B ; 056800~056FFF
	dc.w $F800 ; 057000~0577FF
	dc.w $F800 ; 057800~057FFF
	dc.w $0000 ; 058000~0587FF

	ORG $C20C10   				; Replace palette #3 during loading screen (for debug text)
	dc.w BLACK, WHITE, BLACK

	ORG $C6DEB0
	BINCLUDE "fix_alphabet_bank.bin"

    ORG $C6FEB0
	BINCLUDE "sprites.bin"
