	section data_compiler

;; CPC Mode 1 sprite '_test_sprite_imask_m1_pixels' (sprite_imask)
;; source assets/ball.png region (0,0) 16x16 px -> 4 Mode-1 cols x 2 rows (+extra bottom row)
;; _test_sprite_imask_m1_pixels: 96 body bytes (cs=8, 4 px/cell)
	;; 8 transparent pre-rows before label (safe sub-cell Y, RAGE1 layout)
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
PUBLIC _test_sprite_imask_m1_pixels
_test_sprite_imask_m1_pixels:
	;; Mode-1 col 0 (src col 0, slice 0)
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$10		;; pix ...#
	db	$20		;; pix ..#.
	db	$20		;; pix ..#.
	db	$50		;; pix .#.#
	db	$50		;; pix .#.#
	db	$50		;; pix .#.#
	db	$40		;; pix .#..
	db	$20		;; pix ..#.
	db	$20		;; pix ..#.
	db	$10		;; pix ...#
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	;; Mode-1 col 1 (src col 0, slice 1)
	db	$00		;; pix ....
	db	$30		;; pix ..##
	db	$c0		;; pix ##..
	db	$30		;; pix ..##
	db	$e0		;; pix ###.
	db	$c0		;; pix ##..
	db	$80		;; pix #...
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$c0		;; pix ##..
	db	$30		;; pix ..##
	db	$00		;; pix ....
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	;; Mode-1 col 2 (src col 1, slice 0)
	db	$00		;; pix ....
	db	$c0		;; pix ##..
	db	$30		;; pix ..##
	db	$80		;; pix #...
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$30		;; pix ..##
	db	$c0		;; pix ##..
	db	$00		;; pix ....
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	;; Mode-1 col 3 (src col 1, slice 1)
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$80		;; pix #...
	db	$40		;; pix .#..
	db	$40		;; pix .#..
	db	$20		;; pix ..#.
	db	$20		;; pix ..#.
	db	$20		;; pix ..#.
	db	$20		;; pix ..#.
	db	$40		;; pix .#..
	db	$40		;; pix .#..
	db	$80		;; pix #...
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00		;; pix ....
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
;;;;;;
