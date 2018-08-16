RunDMADirect:
; Using DMA copy causes corruption :( do a CPU copy instead
	move.w  d0,SDREG_GPIO_SET
	add.l   $7EF4(a5),d0		; SectorLoadDest
	movea.l d0,a1
	move.l  $7EF8(a5),a0		; SectorLoadBuffer
	move.l  $7EFC(a5),d7		; SectorLoadSize
	move.l  d7,d6
	andi.b  #31,d7
	lsr.l   #5,d6				; /32 .w?
	; Do as many 32-word copies as possible and top it off with a 1-loop
.copy32:
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	subq.w  #1,d6			; 4
    bne     .copy32			; 10	Total 174 cycles for 32 bytes (5.4 cycles per byte, 453ns per byte, 2155kB/s)
	tst.b   d7
	beq     .exit
.copy2:
	move.w  (a0)+,(a1)+		; 12
	subq.b  #1,d7			; 4
    bne     .copy2			; 10
.exit:
	move.w  d0,SDREG_GPIO_RST
    rts


UploadFIXDMABytes:
	move.l  #$E00000,d0
	add.l   $7EF4(a5),d0		; SectorLoadDest
	movea.l d0,a1
	addq.l  #1,a1
    movea.l $7EF8(a5),a0		; SectorLoadBuffer
    move.l  $7EFC(a5),d7		; SectorLoadSize
.copy:
	move.b  (a0)+,d0			; Read AA BB, store AA 00 BB 00
	move.b  d0,(a1)+			; AA
	move.b  (a0)+,d0
	move.b  d0,1(a1)			; BB
    addq.l  #3,a1
	subq.l  #2,d7				; subq.w ?
    bne     .copy
	move.l  $7EF4(a5),d0		; SectorLoadDest
	add.l   $7EFC(a5),d0		; SectorLoadSize
	add.l   $7EFC(a5),d0		; SectorLoadSize
	move.l  d0,$7EF4(a5)		; SectorLoadDest
	rts
	
CopyBytesToWordCPU:
	move.l  d7,d6
	andi.b  #31,d7
	lsr.l   #4,d6				; /16 .w?
	; Do as many 16-bytes copies as possible and top it off with a 1-loop
.copy16:
	move.b  (a0)+,d0			; 8
	move.w  d0,(a1)+			; 8
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
	subq.w  #1,d6			; 4
    bne     .copy16         ; 10 Total 270 cycles for 16 bytes (16.9 cycles per byte, 1406ns per byte, 694kB/s)
	tst.b   d7
	beq     .exit
.copy1:
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	subq.b  #1,d7			; 4
    bne     .copy1			; 10
.exit:
    rts

; Used for PCM
CopyBytesToWordCPU_OLD:
	addq.l  #1,a1
.copy:
	move.b  (a0)+,(a1)+		; 12
	move.b  (a0)+,1(a1)     ; 16
	addq.l  #1,a1			; 8
	subq.l  #2,d7           ; 8		Can be lowered to 4 cycles if d7 fits in a word (do subq.w)
	beq     .exit			; 8
	move.b  (a0)+,(a1)+		; 12
	move.b  (a0)+,1(a1)     ; 16
	addq.l  #1,a1			; 8
	subq.l  #2,d7           ; 8
	beq     .exit			; 8
	move.b  (a0)+,(a1)+		; 12
	move.b  (a0)+,1(a1)     ; 16
	addq.l  #1,a1			; 8
	subq.l  #2,d7           ; 8
	beq     .exit			; 8
	move.b  (a0)+,(a1)+		; 12
	move.b  (a0)+,1(a1)     ; 16
	addq.l  #1,a1			; 8
	subq.l  #2,d7           ; 8
	bne.s   .copy			; 10	Total 210 cycles for 8 bytes (26.3 cycles per byte, 2192ns per byte, 446kB/s)
.exit:
	rts

UploadZ80DMABytes:
	; Using DMA copy causes corruption :( do a CPU copy instead
	move.l  #$E00000,d0
	add.l   $7EF4(a5),d0		; SectorLoadDest
	movea.l d0,a1
    movea.l $7EF8(a5),a0		; SectorLoadBuffer
    move.l  $7EFC(a5),d7		; SectorLoadSize
.copy:
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	;addq.l  #4,a1
	subq.l  #2,d7				; subq.w ?
    bne     .copy

	move.l  $7EF4(a5),d0		; SectorLoadDest
	add.l   $7EFC(a5),d0		; SectorLoadSize
	add.l   $7EFC(a5),d0		; SectorLoadSize
	move.l  d0,$7EF4(a5)		; SectorLoadDest
	rts
