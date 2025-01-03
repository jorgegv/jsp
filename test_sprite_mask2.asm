	section data_compiler

;; sprite '_test_sprite_mask2_pixels' definition
;; pixel data
;; with extra blank bottom row
;; 
PUBLIC _test_sprite_mask2_pixels	;; 96 bytes 

	db	$ff,$00		;; extra top 7-rows for drawing
	db	$ff,$00		;; _before_ the public sprite label
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00
	db	$ff,$00

_test_sprite_mask2_pixels:
	;; rows: 0-1, col: 0
	db	$f8,$00		;; mask: ##########......   pix: ................
	db	$e0,$03		;; mask: ######..........   pix: ............####
	db	$c0,$0c		;; mask: ####............   pix: ........####....
	db	$80,$13		;; mask: ##..............   pix: ......##....####
	db	$80,$2e		;; mask: ##..............   pix: ....##..######..
	db	$00,$2c		;; mask: ................   pix: ....##..####....
	db	$00,$58		;; mask: ................   pix: ..##..####......
	db	$00,$50		;; mask: ................   pix: ..##..##........
	db	$00,$50		;; mask: ................   pix: ..##..##........
	db	$00,$40		;; mask: ................   pix: ..##............
	db	$00,$20		;; mask: ................   pix: ....##..........
	db	$80,$20		;; mask: ##..............   pix: ....##..........
	db	$80,$10		;; mask: ##..............   pix: ......##........
	db	$c0,$0c		;; mask: ####............   pix: ........####....
	db	$e0,$03		;; mask: ######..........   pix: ............####
	db	$f8,$00		;; mask: ##########......   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................

	;; rows: 0-1, col: 1
	db	$1f,$00		;; mask: ......##########   pix: ................
	db	$07,$c0		;; mask: ..........######   pix: ####............
	db	$03,$30		;; mask: ............####   pix: ....####........
	db	$01,$88		;; mask: ..............##   pix: ##......##......
	db	$01,$04		;; mask: ..............##   pix: ..........##....
	db	$00,$04		;; mask: ................   pix: ..........##....
	db	$00,$02		;; mask: ................   pix: ............##..
	db	$00,$02		;; mask: ................   pix: ............##..
	db	$00,$02		;; mask: ................   pix: ............##..
	db	$00,$02		;; mask: ................   pix: ............##..
	db	$00,$04		;; mask: ................   pix: ..........##....
	db	$01,$04		;; mask: ..............##   pix: ..........##....
	db	$01,$08		;; mask: ..............##   pix: ........##......
	db	$03,$30		;; mask: ............####   pix: ....####........
	db	$07,$c0		;; mask: ..........######   pix: ####............
	db	$1f,$00		;; mask: ......##########   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................
	db	$ff,$00		;; mask: ################   pix: ................

;;;;;;
