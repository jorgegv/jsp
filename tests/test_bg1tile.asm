	section data_compiler

;; tile '_test_bg1tile' definition
;; pixel data
PUBLIC _test_bg1tile_pixels	;; 8 bytes
_test_bg1tile_pixels:
	;; rows: 0-0, col: 0
	db	$88		;; pix: ##......##......
	db	$88		;; pix: ##......##......
	db	$55		;; pix: ..##..##..##..##
	db	$22		;; pix: ....##......##..
	db	$22		;; pix: ....##......##..
	db	$22		;; pix: ....##......##..
	db	$55		;; pix: ..##..##..##..##
	db	$88		;; pix: ##......##......


PUBLIC _test_bg1tile_attr	;; 1 attributes
_test_bg1tile_attr:
	db	71	;; row: 0, col: 0, attr: 01000111b - INK_WHITE | PAPER_BLACK | BRIGHT
;;;;;;;;;;;;

