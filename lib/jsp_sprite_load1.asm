	section code_compiler

	public _jsp_draw_sprite_load1
	public _jsp_move_sprite_load1

	extern _sp1_draw_load1lb
	extern _sp1_draw_load1rb
	extern _sp1_draw_load1
	extern _jsp_draw_sprite
	extern _jsp_move_sprite

	extern jsp_sprite_smc_1
	extern jsp_sprite_smc_2
	extern jsp_sprite_smc_3
	extern jsp_sprite_smc_4
	extern jsp_sprite_smc_5
	extern jsp_sprite_smc_6
	extern jsp_sprite_smc_7

_jsp_draw_sprite_load1:
	ld hl,_jsp_draw_sprite			; patch SMC below
	ld (jsp_sprite_load1_smc+1),hl
	jp _jsp_drawmove_sprite_load1
	
_jsp_move_sprite_load1:
	ld hl,_jsp_move_sprite			; patch SMC below
	ld (jsp_sprite_load1_smc+1),hl
	; fallthrough
	; jp _jsp_drawmove_sprite_load1

_jsp_drawmove_sprite_load1:
	; patch SMCs
	xor a				; a = NOP opcode
	ld (jsp_sprite_smc_1),a

	ld hl,_sp1_draw_load1lb
	ld (jsp_sprite_smc_2+1),hl

	ld hl,_sp1_draw_load1
	ld (jsp_sprite_smc_4+1),hl

	ld hl,_sp1_draw_load1rb
	ld (jsp_sprite_smc_6+1),hl

	ld hl,8
	ld (jsp_sprite_smc_3+1),hl
	ld (jsp_sprite_smc_5+1),hl
	ld (jsp_sprite_smc_7+1),hl

jsp_sprite_load1_smc:
	jp $ffff		; SMC: patched to _jsp_draw_sprite or _jsp_move_sprite
