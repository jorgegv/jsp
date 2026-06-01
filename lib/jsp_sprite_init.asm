	section code_compiler

	public _jsp_init_sprite

; void jsp_init_sprite( struct jsp_sprite_s *sp ) __z88dk_fastcall;
_jsp_init_sprite:
	push ix			; save!
	push hl
	pop ix			; ix = sp

	;     sp->xpos = sp->ypos = 0;
	;     sp->flags.initialized = 1;
	xor a
	IFDEF JSP_TARGET_CPC
	;; CPC layout: xpos +2..+3 (16-bit), ypos +4 (8-bit), flags +5
	ld (ix+2),a
	ld (ix+3),a
	ld (ix+4),a
	set 0,(ix+5)
	ELSE
	;; ZX layout: xpos +2, ypos +3, flags +4
	ld (ix+2),a
	ld (ix+3),a
	set 0,(ix+4)
	ENDIF

	pop ix
	ret
