	section data_compiler

;; CPC Mode 1 sprite '_ball_m1_pixels' (sprite_mask)
;; source assets/ball_m1.png region (0,0) 16x16 px -> 4 Mode-1 cols x 2 rows (+extra bottom row)
;; _ball_m1_pixels: 192 body bytes (cs=16, 4 px/cell)
	;; 8 transparent pre-rows before label (safe sub-cell Y, RAGE1 layout)
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
PUBLIC _ball_m1_pixels
_ball_m1_pixels:
	;; Mode-1 col 0 (src col 0, slice 0)
	db	$ff,$00		;; mask #### pix ....
	db	$ee,$10		;; mask ###. pix ...1
	db	$cc,$30		;; mask ##.. pix ..11
	db	$88,$71		;; mask #... pix .113
	db	$88,$72		;; mask #... pix .131
	db	$00,$f2		;; mask .... pix 1131
	db	$00,$f5		;; mask .... pix 1313
	db	$00,$f5		;; mask .... pix 1313
	db	$00,$f5		;; mask .... pix 1313
	db	$00,$f4		;; mask .... pix 1311
	db	$00,$f2		;; mask .... pix 1131
	db	$88,$72		;; mask #... pix .131
	db	$88,$71		;; mask #... pix .113
	db	$cc,$30		;; mask ##.. pix ..11
	db	$ee,$10		;; mask ###. pix ...1
	db	$ff,$00		;; mask #### pix ....
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	;; Mode-1 col 1 (src col 0, slice 1)
	db	$88,$70		;; mask #... pix .111
	db	$00,$f3		;; mask .... pix 1133
	db	$00,$fc		;; mask .... pix 3311
	db	$00,$f3		;; mask .... pix 1133
	db	$00,$fe		;; mask .... pix 3331
	db	$00,$fc		;; mask .... pix 3311
	db	$00,$f8		;; mask .... pix 3111
	db	$00,$f0		;; mask .... pix 1111
	db	$00,$f0		;; mask .... pix 1111
	db	$00,$f0		;; mask .... pix 1111
	db	$00,$f0		;; mask .... pix 1111
	db	$00,$f0		;; mask .... pix 1111
	db	$00,$f0		;; mask .... pix 1111
	db	$00,$fc		;; mask .... pix 3311
	db	$00,$f3		;; mask .... pix 1133
	db	$88,$70		;; mask #... pix .111
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	;; Mode-1 col 2 (src col 1, slice 0)
	db	$11,$0e		;; mask ...# pix 222.
	db	$00,$cf		;; mask .... pix 3322
	db	$00,$3f		;; mask .... pix 2233
	db	$00,$8f		;; mask .... pix 3222
	db	$00,$0f		;; mask .... pix 2222
	db	$00,$0f		;; mask .... pix 2222
	db	$00,$0f		;; mask .... pix 2222
	db	$00,$0f		;; mask .... pix 2222
	db	$00,$0f		;; mask .... pix 2222
	db	$00,$0f		;; mask .... pix 2222
	db	$00,$0f		;; mask .... pix 2222
	db	$00,$0f		;; mask .... pix 2222
	db	$00,$0f		;; mask .... pix 2222
	db	$00,$3f		;; mask .... pix 2233
	db	$00,$cf		;; mask .... pix 3322
	db	$11,$0e		;; mask ...# pix 222.
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	;; Mode-1 col 3 (src col 1, slice 1)
	db	$ff,$00		;; mask #### pix ....
	db	$77,$08		;; mask .### pix 2...
	db	$33,$0c		;; mask ..## pix 22..
	db	$11,$8e		;; mask ...# pix 322.
	db	$11,$4e		;; mask ...# pix 232.
	db	$00,$4f		;; mask .... pix 2322
	db	$00,$2f		;; mask .... pix 2232
	db	$00,$2f		;; mask .... pix 2232
	db	$00,$2f		;; mask .... pix 2232
	db	$00,$2f		;; mask .... pix 2232
	db	$00,$4f		;; mask .... pix 2322
	db	$11,$4e		;; mask ...# pix 232.
	db	$11,$8e		;; mask ...# pix 322.
	db	$33,$0c		;; mask ..## pix 22..
	db	$77,$08		;; mask .### pix 2...
	db	$ff,$00		;; mask #### pix ....
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
;;;;;;

;; CPC Mode 1 palette for '_ball_m1_pixels' : 4 used pen(s), padded to 4
PUBLIC _ball_m1_palette
_ball_m1_palette:
	db	$54		;; pen  0 = BLACK
	db	$55		;; pen  1 = BRIGHT_BLUE
	db	$52		;; pen  2 = BRIGHT_GREEN
	db	$4b		;; pen  3 = BRIGHT_WHITE
;;;;;;
