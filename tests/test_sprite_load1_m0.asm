	section data_compiler

;; CPC Mode 0 sprite '_test_sprite_load1_m0_pixels' (sprite_load)
;; source assets/ball.png region (0,0) 16x16 px -> 8 Mode-0 cols x 2 rows (+extra bottom row)
;; _test_sprite_load1_m0_pixels: 192 body bytes (cs=8, 2 px/cell)
	;; 8 transparent pre-rows before label (safe sub-cell Y, RAGE1 layout)
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
PUBLIC _test_sprite_load1_m0_pixels
_test_sprite_load1_m0_pixels:
	;; Mode-0 col 0 (src col 0, slice 0)
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$40		;; pix .#
	db	$40		;; pix .#
	db	$40		;; pix .#
	db	$40		;; pix .#
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	;; Mode-0 col 1 (src col 0, slice 1)
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$40		;; pix .#
	db	$80		;; pix #.
	db	$80		;; pix #.
	db	$40		;; pix .#
	db	$40		;; pix .#
	db	$40		;; pix .#
	db	$00		;; pix ..
	db	$80		;; pix #.
	db	$80		;; pix #.
	db	$40		;; pix .#
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	;; Mode-0 col 2 (src col 0, slice 2)
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$c0		;; pix ##
	db	$00		;; pix ..
	db	$c0		;; pix ##
	db	$c0		;; pix ##
	db	$80		;; pix #.
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$c0		;; pix ##
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	;; Mode-0 col 3 (src col 0, slice 3)
	db	$00		;; pix ..
	db	$c0		;; pix ##
	db	$00		;; pix ..
	db	$c0		;; pix ##
	db	$80		;; pix #.
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$c0		;; pix ##
	db	$00		;; pix ..
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	;; Mode-0 col 4 (src col 1, slice 0)
	db	$00		;; pix ..
	db	$c0		;; pix ##
	db	$00		;; pix ..
	db	$80		;; pix #.
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$c0		;; pix ##
	db	$00		;; pix ..
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	;; Mode-0 col 5 (src col 1, slice 1)
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$c0		;; pix ##
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$c0		;; pix ##
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	;; Mode-0 col 6 (src col 1, slice 2)
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$80		;; pix #.
	db	$40		;; pix .#
	db	$40		;; pix .#
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$40		;; pix .#
	db	$40		;; pix .#
	db	$80		;; pix #.
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	;; Mode-0 col 7 (src col 1, slice 3)
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$80		;; pix #.
	db	$80		;; pix #.
	db	$80		;; pix #.
	db	$80		;; pix #.
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00		;; pix ..
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
	db	$00
;;;;;;
