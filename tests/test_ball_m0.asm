	section data_compiler

;; CPC Mode 0 sprite '_ball_m0_pixels' (sprite_mask)
;; source assets/ball_m0.png region (0,0) 16x16 px -> 8 Mode-0 cols x 2 rows (+extra bottom row)
;; _ball_m0_pixels: 384 body bytes (cs=16, 2 px/cell)
	;; 8 transparent pre-rows before label (safe sub-cell Y, RAGE1 layout)
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
PUBLIC _ball_m0_pixels
_ball_m0_pixels:
	;; Mode-0 col 0 (src col 0, slice 0)
	db	$ff,$00		;; mask ## pix ..
	db	$ff,$00		;; mask ## pix ..
	db	$ff,$00		;; mask ## pix ..
	db	$aa,$44		;; mask #. pix .5
	db	$aa,$40		;; mask #. pix .1
	db	$00,$c0		;; mask .. pix 11
	db	$00,$34		;; mask .. pix 26
	db	$00,$34		;; mask .. pix 26
	db	$00,$b4		;; mask .. pix 36
	db	$00,$b4		;; mask .. pix 36
	db	$00,$0c		;; mask .. pix 44
	db	$aa,$04		;; mask #. pix .4
	db	$aa,$54		;; mask #. pix .7
	db	$ff,$00		;; mask ## pix ..
	db	$ff,$00		;; mask ## pix ..
	db	$ff,$00		;; mask ## pix ..
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	;; Mode-0 col 1 (src col 0, slice 1)
	db	$ff,$00		;; mask ## pix ..
	db	$aa,$44		;; mask #. pix .5
	db	$00,$c0		;; mask .. pix 11
	db	$00,$94		;; mask .. pix 16
	db	$00,$38		;; mask .. pix 62
	db	$00,$38		;; mask .. pix 62
	db	$00,$b4		;; mask .. pix 36
	db	$00,$b4		;; mask .. pix 36
	db	$00,$1c		;; mask .. pix 46
	db	$00,$0c		;; mask .. pix 44
	db	$00,$7c		;; mask .. pix 67
	db	$00,$7c		;; mask .. pix 67
	db	$00,$16		;; mask .. pix 86
	db	$00,$03		;; mask .. pix 88
	db	$aa,$41		;; mask #. pix .9
	db	$ff,$00		;; mask ## pix ..
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	;; Mode-0 col 2 (src col 0, slice 2)
	db	$aa,$40		;; mask #. pix .1
	db	$00,$c0		;; mask .. pix 11
	db	$00,$3c		;; mask .. pix 66
	db	$00,$30		;; mask .. pix 22
	db	$00,$3c		;; mask .. pix 66
	db	$00,$3c		;; mask .. pix 66
	db	$00,$2c		;; mask .. pix 64
	db	$00,$0c		;; mask .. pix 44
	db	$00,$fc		;; mask .. pix 77
	db	$00,$fc		;; mask .. pix 77
	db	$00,$03		;; mask .. pix 88
	db	$00,$03		;; mask .. pix 88
	db	$00,$c3		;; mask .. pix 99
	db	$00,$3c		;; mask .. pix 66
	db	$00,$33		;; mask .. pix aa
	db	$aa,$11		;; mask #. pix .a
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	;; Mode-0 col 3 (src col 0, slice 3)
	db	$00,$30		;; mask .. pix 22
	db	$00,$3c		;; mask .. pix 66
	db	$00,$f0		;; mask .. pix 33
	db	$00,$3c		;; mask .. pix 66
	db	$00,$2c		;; mask .. pix 64
	db	$00,$0c		;; mask .. pix 44
	db	$00,$fc		;; mask .. pix 77
	db	$00,$fc		;; mask .. pix 77
	db	$00,$03		;; mask .. pix 88
	db	$00,$03		;; mask .. pix 88
	db	$00,$c3		;; mask .. pix 99
	db	$00,$c3		;; mask .. pix 99
	db	$00,$33		;; mask .. pix aa
	db	$00,$33		;; mask .. pix aa
	db	$00,$3c		;; mask .. pix 66
	db	$00,$f3		;; mask .. pix bb
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	;; Mode-0 col 4 (src col 1, slice 0)
	db	$00,$f0		;; mask .. pix 33
	db	$00,$3c		;; mask .. pix 66
	db	$00,$0c		;; mask .. pix 44
	db	$00,$2c		;; mask .. pix 64
	db	$00,$fc		;; mask .. pix 77
	db	$00,$fc		;; mask .. pix 77
	db	$00,$03		;; mask .. pix 88
	db	$00,$03		;; mask .. pix 88
	db	$00,$c3		;; mask .. pix 99
	db	$00,$c3		;; mask .. pix 99
	db	$00,$33		;; mask .. pix aa
	db	$00,$33		;; mask .. pix aa
	db	$00,$f3		;; mask .. pix bb
	db	$00,$f3		;; mask .. pix bb
	db	$00,$3c		;; mask .. pix 66
	db	$00,$0f		;; mask .. pix cc
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	;; Mode-0 col 5 (src col 1, slice 1)
	db	$55,$08		;; mask .# pix 4.
	db	$00,$0c		;; mask .. pix 44
	db	$00,$3c		;; mask .. pix 66
	db	$00,$fc		;; mask .. pix 77
	db	$00,$03		;; mask .. pix 88
	db	$00,$03		;; mask .. pix 88
	db	$00,$c3		;; mask .. pix 99
	db	$00,$c3		;; mask .. pix 99
	db	$00,$33		;; mask .. pix aa
	db	$00,$33		;; mask .. pix aa
	db	$00,$f3		;; mask .. pix bb
	db	$00,$f3		;; mask .. pix bb
	db	$00,$0f		;; mask .. pix cc
	db	$00,$3c		;; mask .. pix 66
	db	$00,$cf		;; mask .. pix dd
	db	$55,$8a		;; mask .# pix d.
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	;; Mode-0 col 6 (src col 1, slice 2)
	db	$ff,$00		;; mask ## pix ..
	db	$55,$a8		;; mask .# pix 7.
	db	$00,$03		;; mask .. pix 88
	db	$00,$29		;; mask .. pix 68
	db	$00,$96		;; mask .. pix 96
	db	$00,$96		;; mask .. pix 96
	db	$00,$33		;; mask .. pix aa
	db	$00,$33		;; mask .. pix aa
	db	$00,$f3		;; mask .. pix bb
	db	$00,$f3		;; mask .. pix bb
	db	$00,$1e		;; mask .. pix c6
	db	$00,$1e		;; mask .. pix c6
	db	$00,$6d		;; mask .. pix 6d
	db	$00,$cf		;; mask .. pix dd
	db	$55,$2a		;; mask .# pix e.
	db	$ff,$00		;; mask ## pix ..
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	;; Mode-0 col 7 (src col 1, slice 3)
	db	$ff,$00		;; mask ## pix ..
	db	$ff,$00		;; mask ## pix ..
	db	$ff,$00		;; mask ## pix ..
	db	$55,$82		;; mask .# pix 9.
	db	$55,$22		;; mask .# pix a.
	db	$00,$33		;; mask .. pix aa
	db	$00,$79		;; mask .. pix 6b
	db	$00,$79		;; mask .. pix 6b
	db	$00,$2d		;; mask .. pix 6c
	db	$00,$2d		;; mask .. pix 6c
	db	$00,$cf		;; mask .. pix dd
	db	$55,$8a		;; mask .# pix d.
	db	$55,$2a		;; mask .# pix e.
	db	$ff,$00		;; mask ## pix ..
	db	$ff,$00		;; mask ## pix ..
	db	$ff,$00		;; mask ## pix ..
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
;;;;;;

;; CPC Mode 0 palette for '_ball_m0_pixels' : 15 used pen(s), padded to 16
PUBLIC _ball_m0_palette
_ball_m0_palette:
	db	$54		;; pen  0 = BLACK
	db	$53		;; pen  1 = BRIGHT_CYAN
	db	$52		;; pen  2 = BRIGHT_GREEN
	db	$5a		;; pen  3 = LIME
	db	$4a		;; pen  4 = BRIGHT_YELLOW
	db	$57		;; pen  5 = SKY_BLUE
	db	$4b		;; pen  6 = BRIGHT_WHITE
	db	$4e		;; pen  7 = ORANGE
	db	$4d		;; pen  8 = BRIGHT_MAGENTA
	db	$5d		;; pen  9 = MAUVE
	db	$45		;; pen 10 = PURPLE
	db	$47		;; pen 11 = PINK
	db	$59		;; pen 12 = PASTEL_GREEN
	db	$46		;; pen 13 = CYAN
	db	$55		;; pen 14 = BRIGHT_BLUE
	db	$54		;; pen 15 = unused (= pen 0)
;;;;;;
