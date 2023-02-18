;;
;; main.s
;;
;; version 0.0.1
;;
;; by <eatcomics>
;;
;; No notes currently
;;

.include "sfr.i"

;; Game Variables
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
    clr1 p3int, 0	; Cear bit 0 in p3int - For interrupts on button press
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

.main
    ;; Here is where we'll draw the title screen, then we'll wait for a button press and jump to the real game loop
    mov #<title1, trl
    mov #>title1, trh
    inc trl
    inc trl
    call __copytovf
    call __commitvf

.wait_for_start:
    call __pollbuttons
    bn v_btn, b_a, .wati_for_start

    mv #18, vpet_x
    mv #24, vpet_y

.game_loop
    ;;;;; Here there will be a bunch of logic and shiz for the animations, but for now we'll just draw the pet sprite
    call __pollbuttons

.game_logic:
    call __clearvf	; Clear the virtual framebuffer
    call __drawpet	; Draw the pet to the virtual framebuffer
    call __commitvf	; Actually commit sprites to virtual framebuffer

__drawpet:
    ld vpet_x		; Load accumulator with pet x
    st b		; Store in b (for drawing)
    mov #10, acc	; This has to do with the sprite width (I dunno yet, but we'll store in acc as a counter)
    .include sprite "assets/pet.png"	; Waterbear is cool and will import sprites in the format Kresna's LibPerspective uses
