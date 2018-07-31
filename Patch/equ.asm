FixValueList	equ		$10D000	; OK ?		List of values (max 7) used by WriteFix codes $F0+
SDISOStart		equ		$10D100	; Longword
ISOLoadStart	equ		$10D104 ; Longword
SDLoadStart		equ		$10D108 ; Longword
CDSectorCount	equ		$10D10C	; Word
;SDSectorCount	equ		$10D110	; Longword
DebugChecksumIdx equ	$10D120	; Word

FixWriteConfig	equ		$10D120 ; Word		ORed with fix tilemap data to set fix text palette

PCERROR			equ		$10D200	; Longword

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
SDREG_DIN_WORD	equ		$C1E900
