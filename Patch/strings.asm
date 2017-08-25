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
FixStrSubSecCnt:
	dc.b "SUBSECTOR   ",$F0,0

FixStrClear:
    dc.b "            ",0
FixStrSector:
	dc.b "SEC ",$F0,0
