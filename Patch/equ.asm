FixValueList	equ		$10E000	; OK ?		List of values (max 7) used by WriteFix codes $F0+
SDISOStart		equ		$10E100	; Longword
ISOLoadStart	equ		$10E104 ; Longword
SDLoadStart		equ		$10E108 ; Longword
CDSectorCount	equ		$10E10C	; Word
;SDSectorCount	equ		$10E110	; Longword

FixWriteConfig	equ		$10E120 ; Word		ORed with fix tilemap data to set fix text palette

PCERROR			equ		$10E200	; Longword

; HW registers:
SDREG_DOUTBASE	equ		$C1E000
SDREG_CSLOW		equ		$C1E300
SDREG_CSHIGH	equ		$C1E310
SDREG_LOWSPEED	equ		$C1E400
SDREG_HIGHSPEED	equ		$C1E410
SDREG_UNLOCK	equ		$C1E500
SDREG_LOCK		equ		$C1E510
SDREG_STATUS	equ		$C1E600
SDREG_INITBURST equ		$C1E700
SDREG_DIN		equ		$C1E800
