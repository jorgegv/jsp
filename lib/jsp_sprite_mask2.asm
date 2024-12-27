	section code_compiler

	public _jsp_draw_sprite_mask2
	public _jsp_move_sprite_mask2

	extern _sp1_draw_mask2lb
	extern _sp1_draw_mask2rb
	extern _sp1_draw_mask2
	extern _jsp_draw_sprite
	extern _jsp_move_sprite

	extern jsp_sprite_smc_1
	extern jsp_sprite_smc_2
	extern jsp_sprite_smc_3
	extern jsp_sprite_smc_4
	extern jsp_sprite_smc_5
	extern jsp_sprite_smc_6
	extern jsp_sprite_smc_7

_jsp_draw_sprite_mask2:
	ld hl,_jsp_draw_sprite		; patch SMC below
	ld (jsp_sprite_mask2_smc+1),hl
	jp _jsp_drawmove_sprite_mask2
	
_jsp_move_sprite_mask2:
	ld hl,_jsp_move_sprite		; patch SMC below
	ld (jsp_sprite_mask2_smc+1),hl
	; fallthrough
	; jp _jsp_drawmove_sprite_mask2

_jsp_drawmove_sprite_mask2:
	; patch SMCs
	ld a,$29				; a = ADD HL,HL opcode
	ld (jsp_sprite_smc_1),a

	ld hl,_sp1_draw_mask2lb
	ld (jsp_sprite_smc_2+1),hl

	ld hl,_sp1_draw_mask2
	ld (jsp_sprite_smc_4+1),hl

	ld hl,_sp1_draw_mask2rb
	ld (jsp_sprite_smc_6+1),hl

	ld hl,16
	ld (jsp_sprite_smc_3+1),hl
	ld (jsp_sprite_smc_5+1),hl
	ld (jsp_sprite_smc_7+1),hl

jsp_sprite_mask2_smc:
	jp $ffff		; SMC: patched to _jsp_draw_sprite or _jsp_move_sprite
