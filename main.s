;;
;; main.s
;;
;; version 0.0.1
;;
;; by <eatcomics>
;;
;; No notes currently
;;

.include "sfr.s"

;; Game Variables
pet_x	= $30	; X position of the pet
pet_y	= $31	; Y position of the pet
gotbtns = $36	; Buttons currently being pressed
time	= $37	; Time for animation of vpet sprite

b_sleep = $7	; Sleep button position
b_mode	= $6	; Mode button position
b_b	= $5	; B
b_a	= $4	; A
b_r	= $3	; Right
b_l	= $2	; Left
b_d	= $1	; Down
b_u	= $0	; Up

;; Reset and interrupt vectors
.org $00	; Reset Vector
jmpff __main	; Jump to vmupet entry point

.org $03	; INT0 (external)
jmp __nop_vec

.org $0B	; INT1 (external)
jmp __nop_vec

.org $13	; INT2 (external) or T0L overflow
jmp __nop_vec

.org $1B	; INT3 (external or base timer overflow
jmp __nop_vec

.org $23	; T0H overflow
jmp __nop_vec

.org $2B	; T1H or T1L overflow
jmp __nop_vec

.org $33	; SIO0
jmp __nop_vec

.org $3B	; SIO1
jmp __nop_vec

.org $43	; RFB
jmp __nop_vec

.org $4B	; P3
jmp __nop_vec

__nop_vec:
    reti	; Return, used for unnecessary interrupts (ISRs)

    .org $130	; Firmware entry vector - Update system time
__time_vec:
    push ie
    clr1 ie, 7
    not1 ext, 0
    jmpf __time_vec
    pop ie
    reti

    .org $1F0	; Frimware entry vector - Leave game mode
__goodbye:
    not1 ext, 0
    jmpf __goodbye

;; VMS File Header
    .org $200			; Header starts at $200 for games
    .text 16 "VMUPET"		; 16 bytes for file description
    .text 32 "VMUPET FOR VMU"	; 32 bytes of file description (for dreamcast)
    .string 16 "" 		; Identifier of application that created the file (we don't need it)

    .include icon "./assets/icon.png" ; waterbear handles this nicely, nice clean code for us!

;; Finally our code! Main entry point
    .org $680	; Main starts at $680
__main:
