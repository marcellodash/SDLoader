	ORG $C0BBC8					; Replacement to avoid using DMA copy
	dc.l UploadPRGDMAWords
	ORG $C0BBD4					; Replacement to avoid using DMA copy
	dc.l UploadZ80DMABytes
	ORG $C0BBE8					; Replacement to avoid using DMA copy
	dc.l UploadPRGDMAWords
	
	; TODO: Re-enable this when loading will work !
	;ORG $C0BF5E
	;jmp     CopyBytesToWordCPULoop	; Cache-to-DRAM copy speed optimization attempt to speed up PCM loads

	ORG $C0C1F6
	dc.l   CDPlayerVBLProc		; Replace pointer to CDPlayerVBLProc by one to new code

	ORG $C0C360
	nop							; Bypass CD lid check in SYSTEM_INT1
	nop

    ORG $C0C854
	jmp    PUPPETStuff			; Insertion - Called at startup, initializes SD card
	
    ORG $C0CA28
	jsr    InitRAM				; Insertion - Avoid tripping in-game copy protections
	nop

    ORG $C0CBD2
	nop							; Bypass CD lid check in SYSTEM_IO
	nop

	ORG $C0E5DE
	jmp    $C0E626				; Prevents drawing of the "NOW LOADING" box

	ORG $C0E712
	jmp    DrawProgressAnimation	; Replaces custom loading animation code with current sector display

	ORG $C0E89C
	jmp    ParseSDFiles			; Added to InitCDPlayerScreen

	; TEMPORARY, TO REMOVE
	; Disables call to CheckCDValid
	;ORG $C0E8AA
	;nop
	;nop

	ORG $C0E8D2
	bra    $C0E968             	; Skip CD player interface updating, just go to rts

	ORG $C0EB96
	nop							; Disable CDValidFlag check
	nop
	nop
	nop
	nop                         ; Disable CD mech detection in CheckCDValid
	nop                         ; Overwrite up to movem.l ...
	nop
	nop
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

	ORG $C0F324
	bra     $C0F348				; Prevent loading custom loading screens
	ORG $C0F382
	bra     $C0F3AA             ; Same
	
	ORG $C0F4E8					; Disable waiting for CD to stop after BIOSF_LOADFILE
	nop
	nop

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

	ORG $C11788
	rts
	;;jsr     $C0B278			; Todo: Just jump to ClearSprites ?
	;lea     $100040,a6        	; Disable CD player display and erase finger cursor from splash screen
	;move.b  #0,4(a6)			; Sprite height
	;bra     $C16CF2			; "SpriteUpdateVRAM"
	
	ORG $C167FE
	moveq.l #1,d0
	move.b  d0,$764E(a5)
	move.b  d0,$7656(a5)		; Init "CDValidFlag" to 1 instead of 0 to kickstart CD checking

	ORG $C20BE0
	dc.w $4CF0					; Make the loading bar green, just for fun :]
	dc.w $5AF0
	dc.w $28F0
	dc.w $24F0
	dc.w $20D0
