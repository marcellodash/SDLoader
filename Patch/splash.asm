	ORG $C168C0
	move.l #360,$101B2E			; Reduce splash duration (10s -> 6s)
	

	ORG $C16E00
	dc.w 96						; X position for SD card image

    ORG $C20080
	BINCLUDE "sdcard.map"		; Replaces CD image

    ORG $C20A8E
	BINCLUDE "sdcard.pal" 		; Replaces CD palette


	ORG $C16E14
	dc.w 112					; X position for finger image
	dc.w 48						; Y position

	ORG $C20102
	BINCLUDE "finger.map"		; Replaces faces image (smaller)

	ORG $C20A4E
	BINCLUDE "finger.pal"		; Replaces faces palette


	ORG $C201C2
	BINCLUDE "S.map"

	ORG $C201CC
	BINCLUDE "D.map"

	ORG $C16ED0
	dc.w $F4					; "D" final X position


	ORG $C16DAC
	move.b  d2,(4,a6)			; Sprite height bugfix :)

	ORG $C16C12
	move.l  #$50000,d0			; Loop curve width (oval)

	ORG $C16BAA
	move.l  #$920000,$20(a6)	; Loop start X position
