    ORG $C00408
	jmp     ErrBus
	
    ORG $C0040E
	jmp     ErrAddr

    ORG $C00414
	jmp     ErrIllegal

    ORG $C00426
	jmp     ErrGeneric

    ORG $C0042C
	jmp     ErrUninit
