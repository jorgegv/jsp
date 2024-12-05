
; DRAW MASK SPRITE 2 BYTE DEFINITION NO ROTATION
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	section code_compiler

	public _SP1_DRAW_MASK2NR

;  a = hor rot table
; bc = graphic disp
; hl = graphic def ptr
; de = left graphic def ptr

_SP1_DRAW_MASK2NR:

   ; hl = sprite def = (mask,graph) pairs
   ; bc = bg cell
   ; 0

   push bc
   pop ix	; ix = dst buffer

   ld e,(ix+0)
   ld d,(ix+1)
   ld a,(hl)
   and e
   inc hl
   or (hl)
   inc hl
   ld (ix+0),a
   ld a,(hl)
   and d
   inc hl
   or (hl)
   inc hl
   ld (ix+1),a

   ; 1

   ld e,(ix+3)
   ld d,(ix+2)
   ld a,(hl)
   and e
   inc hl
   or (hl)
   inc hl
   ld (ix+2),a
   ld a,(hl)
   and d
   inc hl
   or (hl)
   inc hl
   ld (ix+3),a

   ; 2

   ld e,(ix+4)
   ld d,(ix+5)
   ld a,(hl)
   and e
   inc hl
   or (hl)
   inc hl
   ld (ix+4),a
   ld a,(hl)
   and d
   inc hl
   or (hl)
   inc hl
   ld (ix+5),a

   ; 3

   ld e,(ix+6)
   ld d,(ix+7)
   ld a,(hl)
   and e
   inc hl
   or (hl)
   inc hl
   ld (ix+6),a
   ld a,(hl)
   and d
   inc hl
   or (hl)
   ld (ix+7),a

   ret
