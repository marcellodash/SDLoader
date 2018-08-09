    cpu 68000
    supmode on
    INCLUDE "regdefs.asm"
	INCLUDE "equ.asm"
    INCLUDE "vectors.asm"
	INCLUDE "splash.asm"

	; !!! See doc.odt !!!

	; Patches ---------------------------

	ORG $C0BBC8					; Replacement
	dc.l UploadPRGDMAWords
	ORG $C0BBD4					; Replacement
	dc.l UploadZ80DMABytes
	ORG $C0BBE8					; Replacement
	dc.l UploadPRGDMAWords

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
	;jmp     CopyBytesToWordCPULoop	; Cache-to-DRAM copy speed optimization attempt to speed up PCM loads

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

	;NOT USEFUL, CAN REMOVE
	;ORG $C0EE58
	;rts						; Disable SetCDDMode as a whole

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
	bra     MemoryViewer
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
	lsl.l   #2,d0				; CD sector = 2048 bytes = 4 SD sectors = 4 * 512 bytes

    lea     FixValueList,a0
	move.l  d0,(a0)
    lea     FixStrSDSecCnt,a0
	move.w  #FIXMAP+10+(6*32),d0
	jsr     WriteFix            ; Display total number of SD sectors to load
	move.b  d0,REG_DIPSW

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

	
UploadPRGDMAWords:
	; Using DMA copy causes corruption :( do a CPU copy instead
	move.l  $7EF4(a5),a1
	move.l  $7EF8(a5),a0
	move.w  #1024,d7
.copy:
	move.w  (a0)+,(a1)+
	subq.w  #1,d7
    bne     .copy
    
	move.l  $7EF4(a5),d0
	add.l   $7EFC(a5),d0
	move.l  d0,$7EF4(a5)
	rts
	
UploadZ80DMABytes:
	; Using DMA copy causes corruption :( do a CPU copy instead
	move.l  #$E00000,d0
	add.l   $7EF4(a5),d0
	movea.l d0,a1
    movea.l $7EF8(a5),a0
    move.l  $7EFC(a5),d7
.copy:
	move.b  (a0)+,d0
	move.w  d0,(a1)
	move.b  (a0)+,d0
	move.w  d0,2(a1)
	addq.l  #4,a1
	subq.l  #2,d7
    bne     .copy

	move.l  $7EF4(a5),d0
	add.l   $7EFC(a5),d0
	add.l   $7EFC(a5),d0
	move.l  d0,$7EF4(a5)
	rts

    INCLUDE "exceptions.asm"
	INCLUDE "print.asm"
	INCLUDE "sdcard.asm"
	INCLUDE "fat32.asm"
	INCLUDE "strings.asm"

	padding on

	ORG $C20C10   				; Replace palette #3 during loading screen (for debug text)
	dc.w BLACK, WHITE, BLACK

	ORG $C6DEB0
	BINCLUDE "fix_alphabet_bank.bin"

    ORG $C6FEB0
	BINCLUDE "sprites.bin"
