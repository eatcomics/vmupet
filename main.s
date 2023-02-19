;;
;; main.s
;;
;; version 0.0.1
;;
;; by <eatcomics>
;;
;; No notes currently
;;

.include "lib/sfr.i"

;; Game Variables
v_btn		= $10	; Current active state of buttons
v_btn_old	= $11	; Previous state of buttons
v_btn_chg	= $12	; Which buttons have chnaged from v_btn_old to v_btn

pet_x		= $30	; X position of the pet			1 byte
pet_y		= $31	; Y position of the pet			1 byte
pet_width	= $32	; Width of pet sprite			1 byte
pet_height	= $33	; Height of pet sprite			1 byte
pet_spr_addr	= $34	; Location of sprite in memory		2 bytes

gotbtns 	= $36	; Buttons currently being pressed	1 byte
time		= $37	; Time for animation of vpet sprite	? bytes
rseed		= $3c	; RNG seed

b_sleep = $7	; Sleep
b_mode	= $6	; Mode
b_b	= $5	; B
b_a	= $4	; A
b_r	= $3	; Right
b_l	= $2	; Left
b_d	= $1	; Down
b_u	= $0	; Up

;; Reset and interrupt vectors
.org $00	; Reset Vector
jmpf __main	; Jump to vmupet entry point

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
__time1int:
    push ie
    clr1 ie, 7
    not1 ext, 0
    jmpf __time1int
    pop ie
    reti

    .org $1F0	; Frimware entry vector - Leave game mode
__goodbye:
    not1 ext, 0
    jmpf __goodbye

;; VMS File Header
    .org $200			; Header starts at $200 for games
    .text 16 "VMUPet"		; 16 bytes for file description
    .text 32 "VMUPet for VMU"	; 32 bytes of file description (for dreamcast)
    .string 16 "" 		; Identifier of application that created the file (we don't need it)

    .include icon "./assets/icon.png" ; waterbear handles this nicely, nice clean code for us!

;; Finally our game code! Main entry point
    .org $680	; Main starts at $680
__main:
    clr1 ie, 7		; Disable interrupts until hardware is initialized
    mov #$a1, ocr	; Set up OCR, I don't know if this is what I want or not REVIEW THIS LATER
    mov #$09, mcr	; Set up Mode Control Register
    mov #$80, vccr	; Set up LCD Contrast Control Register
    clr1 p3int, 0	; Clear bit 0 in p3int - For interrupts on button press
    clr1 p1, 7		; Sets the sound output port
    mov #$FF, p3	; p3 are buttons - 0 for pressed 1 for unpressed

    clr1 psw, 1		; Create random seed using current date/time of system	
    ld $1c
    xor $1d
    set1 psw,1
    st rseed

    ; Indirect addressing time
    clr1 psw, 4		; I dunno what this shit does, I should read, but too tired
    clr1 psw, 3
    mov #$82, $2
    mov #2, xbnk
    st @R2
    set1 ie, 7		; Reenable interrupts now that hardware is initialized

    call __pollbuttons	; Get the initial button state

    ;;; This is initing variables for the Pet Sprite, should probably put this somewhere else...
    ld 		pet_x		; Load accumulator with pet x
    st 		b		; Store in b (for drawing)
    mov 	#20, acc	; Sprite width is 32
    mov 	#<pet_spr, acc
    st		trl
    st		pet_spr_addr
    mov 	#>pet_spr, acc
    st		trh
    st		pet_spr_addr+1
    xor		acc
    ldc
    st		pet_width
    mov 	#1, acc
    ldc
    st		pet_height

.main
    ;; Here is where we'll draw the title screen, then we'll wait for a button press and jump to the real game loop
    mov			#<title1, trl
    mov			#>title1, trh
    inc trl
    inc trl

.wait_for_start:
    call __pollbuttons
    bn v_btn, b_a, .wait_for_start

    mov #0, pet_x
    mov #0, pet_y

.game_loop
    ;;;;; Here there will be a bunch of logic and shiz for the animations, but for now we'll just draw the pet sprite
    call __pollbuttons

.game_logic:
    call __drawpet	; Draw the pet to the virtual framebuffer

__drawpet:
    P_Draw_Sprite 	pet_spr_addr, pet_x, pet_y
    P_Blit_Screen
    
__pollButtons:
    bp p7, 0, .quit	; When the VMU is plugged into controller, this bit goes high
    push acc		; Save acc so we can use it for reading and storing
    ld v_btn		; The current set of buttons is now the old set
    st v_btn_old
    ld p3		; Read value of port 3 (buttons)
    bn acc, 6, .quit	; Bit 6 is the mode button, it will quit
    xor #$FF		; Invert button state, so 1=Pressed 0=Unpressed
    st v_btn		; The current set of buttons is now the new set just read
    xor v_btn_old	; XOR the new set with the old set, this will give us changed buttons
    st v_btn_chg
    pop acc
    ret
.quit:			; When the VMU is plugged in to controller quit the game
    jmp __goodbye

.include "lib/libperspective.asm"	; Kresna's lib perspective for fancy sprite drawing macros
;.include "lib/libkcommon.asm"		; libperspective needs this I think
title1:
	.include sprite "assets/title1.png"
pet_spr: 
	.include sprite "assets/pet.png"	; Waterbear is cool and will import sprites in the format Kresna's LibPerspective uses


