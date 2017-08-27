	PADDING OFF

;$00: End of string
;$01: Move from origin X, Y
;$Fx: Print stored longword
FixStrReqSec:
    dc.b "LOAD MMSSFF ",$F0,0
FixStrIsoAddr:
    dc.b "ISO ADDRESS ",$F0,0
FixStrCDSecCnt:
	dc.b "CD SECTORS  ",$F0,0
FixStrSDAddr:
	dc.b "SD ADDRESS  ",$F0,0
FixStrSDSecCnt:
	dc.b "SD SECTORS  ",$F0,0
FixStrCurAddr:
	dc.b "CUR ADDRESS ",$F0," ",$F1,0

FixStrClear:
    dc.b "            ",0
FixStrSector:
	dc.b "SEC ",$F0,0

FixStrOhCrap:
    dc.b "OH CRAP :(",0
FixStrErrBus:
    dc.b "BUS ERROR",0
FixStrErrAddr:
    dc.b "ADDRESS ERROR",0
FixStrErrIllegal:
    dc.b "ILLEGAL INSTRUCTION",0
FixStrErrGeneric:
    dc.b "RESET3 ERROR",0
FixStrErrUninit:
    dc.b "UNINIT. VECTOR",0
FixStrDRegsDump:
    dc.b "D0:",$F0,1,0,1
    dc.b "D1:",$F1,1,0,2
    dc.b "D2:",$F2,1,0,3
    dc.b "D3:",$F3,1,0,4
    dc.b "D4:",$F4,1,0,5
    dc.b "D5:",$F5,1,0,6
    dc.b "D6:",$F6,1,0,7
    dc.b "D7:",$F7,0
FixStrARegsDump:
    dc.b "A0:",$F0,1,0,1
    dc.b "A1:",$F1,1,0,2
    dc.b "A2:",$F2,1,0,3
    dc.b "A3:",$F3,1,0,4
    dc.b "A4:",$F4,1,0,5
    dc.b "A5:",$F5,1,0,6
    dc.b "A6:",$F6,1,0,7
    dc.b "PC:",$F7,0
