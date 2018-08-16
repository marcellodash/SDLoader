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
	dc.b "CUR ADDRESS ",$F0,0
	
FixStrViewAddr:
	dc.b $F0,0

FixStrClear:
    dc.b "            ",0
FixStrSector:
	dc.b "SEC ",$F0,0
StrFAT32:
    dc.b "FAT32",0
FixStrClusterIdx:
	dc.b "",$F0,0

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

ErrFixStrList:
    dc.l FixStrInterfaceTimeout
    dc.l FixStrCMD0Timeout
    dc.l FixStrSDInitFailed
    dc.l FixStrSDWrongStatus
    dc.l FixStrCMD16Failed
    dc.l FixStrDataTokenTimeout
    dc.l FixStrStopReadFailed
    dc.l FixStrStartReadFailed
    dc.l FixStrBadSignature
    dc.l FixStrBadFSType
    dc.l FixStrCMD8Timeout

FixStrInterfaceTimeout:				; 0
	dc.b "SPI interface timeout",0
FixStrCMD0Timeout:					; 1
	dc.b "CMD0 timeout",0
FixStrSDInitFailed:					; 2
	dc.b "SD init failed",0
FixStrSDWrongStatus:                ; 3
	dc.b "SD wrong status",0
FixStrCMD16Failed:					; 4
	dc.b "CMD16 failed",0
FixStrDataTokenTimeout:				; 5
	dc.b "Data token timeout",0
FixStrStopReadFailed:				; 6
	dc.b "Read stop failed",0
FixStrStartReadFailed:				; 7
	dc.b "Read start failed",0
FixStrBadSignature:					; 8
	dc.b "Bad boot record signature",0
FixStrBadFSType:					; 9
	dc.b "Filesystem is not FAT32",0
FixStrCMD8Timeout:					; 10
	dc.b "CMD8 timeout",0
