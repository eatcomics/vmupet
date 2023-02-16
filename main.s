;;
;; main.s
;;
;; version 0.0.1
;;
;; by <Eatcomics>
;;
;; No notes currently
;;

.include "sfr.i"

;; Game Variables
pet_x = $30	; X position of the pet
pet_y = $31	; Y position of the pet
gotbtns = $36	; Buttons currently being pressed
time = $37	; Time for animation of vpet sprite
