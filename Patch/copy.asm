; TODO: Check first if the copy size is a multiple of 8 !
CopyBytesToWordCPULoop:
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
	subq.l  #8,d7
	bne.s   CopyBytesToWordCPULoop

	rts

	
UploadPRGDMAWords:
	; Using DMA copy causes corruption :( do a CPU copy instead
	move.l  $7EF4(a5),a1
	move.l  $7EF8(a5),a0
	move.w  #1024,d7
.copy:
	move.w  (a0)+,(a1)+
	subq.w  #1,d7
    bne     .copy
    
	move.l  $7EF4(a5),d0
	add.l   $7EFC(a5),d0
	move.l  d0,$7EF4(a5)
	rts
	
UploadZ80DMABytes:
	; Using DMA copy causes corruption :( do a CPU copy instead
	move.l  #$E00000,d0
	add.l   $7EF4(a5),d0
	movea.l d0,a1
    movea.l $7EF8(a5),a0
    move.l  $7EFC(a5),d7
.copy:
	move.b  (a0)+,d0
	move.w  d0,(a1)
	move.b  (a0)+,d0
	move.w  d0,2(a1)
	addq.l  #4,a1
	subq.l  #2,d7
    bne     .copy

	move.l  $7EF4(a5),d0
	add.l   $7EFC(a5),d0
	add.l   $7EFC(a5),d0
	move.l  d0,$7EF4(a5)
	rts
	