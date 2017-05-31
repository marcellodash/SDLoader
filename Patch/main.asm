    cpu 68000
    supmode on
    INCLUDE "regdefs.asm"

	ORG $C16E00
	dc.w 96						; X position

    ORG $C20080
	BINCLUDE "sdcard.map"

    ORG $C20A8E
	BINCLUDE "sdcard.pal"


	ORG $C16E14
	dc.w 112					; X position
	dc.w 48						; Y position

	ORG $C20102
	BINCLUDE "finger.map"

	ORG $C20A4E
	BINCLUDE "finger.pal"
	
	
	ORG $C201C2
	BINCLUDE "S.map"

	ORG $C201CC
	BINCLUDE "D.map"

	ORG $C16ED0
	dc.w $F4					; "D" final X position

	

	ORG $C16DAC
	move.b  d2,(4,a6)			; Sprite height bugfix :)

	ORG $C16C12
	move.l  #$50000,d0			; Curve width

	ORG $C16BAA
	move.l  #$920000,$20(a6)	; Curve start



    ORG $C6FEB0
	BINCLUDE "sprites.bin"
