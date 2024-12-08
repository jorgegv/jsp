
; DRAW MASK SPRITE 2 BYTE DEFINITION ROTATED, ON LEFT BORDER
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	section code_compiler

	public _SP1_DRAW_MASK2LB
	public _SP1_DRAW_MASK2LB_ALT

	extern _SP1_DRAW_MASK2NR
	extern _jsp_rottbl

;  a = hor rot table
; bc = graphic disp
; hl = graphic def ptr
; de = left graphic def ptr

_SP1_DRAW_MASK2LB:

   cp _jsp_rottbl/256
   jp z, _SP1_DRAW_MASK2NR

   ld d,a

_SP1_DRAW_MASK2LB_ALT:

   push ix	; save!

   push bc
   pop ix

   ;  d = shift table
   ; hl = sprite def (mask,graph) pairs
   ; ix = dst buf  

   ld e,$ff
   ld a,(de)
   cpl
   exx
   ld b,a
   exx

_SP1Mask2LBRotate:

   ; 0

   ld c,(ix+0)
   ld b,(ix+1)
   ld e,(hl)
   inc hl
   ld a,(de)
   exx
   or b
   exx
   and c
   ld c,a
   ld e,(hl)
   inc hl
   ld a,(de)
   or c
   ld (ix+0),a
   ld e,(hl)
   inc hl
   ld a,(de)
   exx
   or b
   exx
   and b
   ld b,a
   ld e,(hl)
   inc hl
   ld a,(de)
   or b
   ld (ix+1),a

   ; 1

   ld c,(ix+2)
   ld b,(ix+3)
   ld e,(hl)
   inc hl
   ld a,(de)
   exx
   or b
   exx
   and c
   ld c,a
   ld e,(hl)
   inc hl
   ld a,(de)
   or c
   ld (ix+2),a
   ld e,(hl)
   inc hl
   ld a,(de)
   exx
   or b
   exx
   and b
   ld b,a
   ld e,(hl)
   inc hl
   ld a,(de)
   or b
   ld (ix+3),a

   ; 2

   ld c,(ix+4)
   ld b,(ix+5)
   ld e,(hl)
   inc hl
   ld a,(de)
   exx
   or b
   exx
   and c
   ld c,a
   ld e,(hl)
   inc hl
   ld a,(de)
   or c
   ld (ix+4),a
   ld e,(hl)
   inc hl
   ld a,(de)
   exx
   or b
   exx
   and b
   ld b,a
   ld e,(hl)
   inc hl
   ld a,(de)
   or b
   ld (ix+5),a

   ; 3

   ld c,(ix+6)
   ld b,(ix+7)
   ld e,(hl)
   inc hl
   ld a,(de)
   exx
   or b
   exx
   and c
   ld c,a
   ld e,(hl)
   inc hl
   ld a,(de)
   or c
   ld (ix+6),a
   ld e,(hl)
   inc hl
   ld a,(de)
   exx
   or b
   exx
   and b
   ld b,a
   ld e,(hl)
   ld a,(de)
   or b
   ld (ix+7),a

   pop ix	; restore!
   ret
