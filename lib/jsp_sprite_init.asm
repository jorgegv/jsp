	section code_compiler

	public _jsp_init_sprite

; void jsp_init_sprite( struct jsp_sprite_s *sp ) __z88dk_fastcall;
_jsp_init_sprite:
	push ix			; save!
	push hl
	pop ix			; ix = sp

	;     sp->xpos = sp->ypos = 0;
	xor a
	ld (ix+2),a
	ld (ix+3),a

	;     sp->flags.initialized = 1;
	set 0,(ix+4)

	pop ix
	ret
