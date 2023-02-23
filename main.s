;;
;; main.s
;;
;; version 0.0.1
;;
;; by <eatcomics>
;;
;; No notes currently
;;

;; TODO
;; In main branch stop using libperspective and the other one, just use shiro's input code and drawing code
;; Move those into their own file along with sleep and quit
;; Move sprite every frame
;; Change sprite based on direction and walking

.include "lib/sfr.i"

;; Game Variables
pet_x		= $16    ; X position of the pet                1 byte
pet_y		= $11    ; Y position of the pet                1 byte
pet_width	= $12    ; Width of pet sprite                  1 byte
pet_height	= $13    ; Height of pet sprite                 1 byte
pet_spr_addr	= $14    ; Location of sprite in memory         2 bytes

time		= $37    ; Time for animation of vpet sprite    ? bytes
rseed		= $3c    ; RNG seed

title_spr_addr  = $8     ; Location of title in memory          2 bytes

;; Libkcommon uses these
p3_pressed              =       $4      ; 1 byte
p3_last_input           =       $5      ; 1 byte

;; Reset and interrupt vectors
    .org $00        ; Reset Vector
    jmpf __main     ; Jump to vmupet entry point
    
    .org $03        ; INT0 (external)
    reti
    
    .org $0B        ; INT1 (external)
    reti
    
    .org $13        ; INT2 (external) or T0L overflow
    reti
    
    .org $1B        ; INT3 (external or base timer overflow
    jmpf __time1int
    
    .org $23        ; T0H overflow
    reti
    
    .org $2B        ; T1H or T1L overflow
    reti
    
    .org $33        ; SIO0
    reti
    
    .org $3B        ; SIO1
    reti
    
    .org $43        ; RFB
    reti
    
    .org $4B        ; Clear Port 3 interrupts
    clr1    p3int, 0
    clr1    p3int, 1
    reti

.org $130    ; Firmware entry vector - Update system time
__time1int:
    push    ie
    clr1    ie, 7
    not1    ext, 0
    jmpf    __time1int
    pop     ie
    reti

    .org $1F0    ; Firmware entry vector - Leave game mode
goodbye:
    not1    ext, 0
    jmpf    goodbye

;; VMS File Header
    .org    $200                ; Header starts at $200 for games
    .text   16 "VMUPet"         ; 16 bytes for file description
    .text   32 "VMUPet for VMU"	; 32 bytes of file description (for dreamcast)
    .string 16 ""               ; Identifier of application that created the file (we don't need it)

    .include icon "./assets/icon.png" ; Waterbear handles this nicely, nice clean code for us!

;; Finally our game code! Main entry point
    .org   $54B	          ; Main starts at $54B if you have one title screen, $680 if two
__main:
    clr1 ie, 7            ; Disable interrupts until hardware is initialized
    mov #$a1, ocr         ; Set up OCR, I don't know if this is what I want or not REVIEW THIS LATER
    mov #$09, mcr         ; Set up Mode Control Register
    mov #$80, vccr        ; Set up LCD Contrast Control Register
    clr1 p3int, 0         ; Clear bit 0 in p3int - For interrupts on button press
    clr1 p1, 7            ; Sets the sound output port
    mov #$FF, p3          ; p3 are buttons - 0 for pressed 1 for unpressed

;    clr1 psw, 1           ; Create random seed using current date/time of system	
;    ld $1c
;    xor $1d
;    set1 psw,1
;    st rseed

    ; Indirect addressing time
    ;; Shiro was using this as a virtual buffer so he could do a frame swap using xram
    ;clr1    psw, 4
    ;clr1    psw, 3
    ;mov     #$82, $2
    ;mov     #2, xbnk
    ;st      @R2


    set1    ie, 7            ; Reenable interrupts now that hardware is initialized

    call   Get_Input         ; Get the initial button state

    ;; Here is where we'll draw the title screen, then we'll wait for a button press and jump to the real game loop
    ;;;;;; Since this is the first time we're running into this, let's break it down, sexual style
    ;; The VMU is wierd, and because of a bunch of nonsense with it, it uses 9 bits for addressing, it's a whole thing
    ;; So because of that, there's some magic with things called banks. And to utilize this wonderful 9 bit addressing you have
    ;; to use indirect addressing, so just keep that in mind when reading the comments below
    ;; 
    ;; This basically just gets a pointer to the sprite data, and sets the height and width of a sprite
    mov    #<title1, acc       ; Load the lower byte of title1 data from the bank to the accumulator
    st     trl                 ; Store that shit in the Table Reference Register lower byte
    st     title_spr_addr      ; Store that in title_spr_addr as well, we'll pass this to LibPerspective to draw
    mov    #>title1, acc       ; Now we repeat with the high byte of title1
    st     trh                 ; Store that shit in the Table Reference Register upper byte
    st     title_spr_addr+1    ; Also, store that high byte in the high byte of title_spr_addr
    xor    acc                 ; Xor acc
    ldc                        ; ldc adds what's in the acc with trl+trh, then writes that address back to acc

    mov    #<pet_spr, acc    ; This is all indirect addressing magic, I'll read about
    st     trl               ;     someday soon
    st     pet_spr_addr
    mov    #>pet_spr, acc
    st     trh
    st     pet_spr_addr+1
    xor    acc
    ldc
    mov    #16, pet_width
    mov    #16, pet_height

    ;; Actually draw and render the title sprite
    P_Draw_Background    title_spr_addr
    P_Blit_Screen

.wait_for_start:
    call    Get_Input
    clr1    ocr, 5
    
    set1    ocr, 5
    
    mov     #Button_A, acc
    call    Check_Button_Pressed
    bz      .wait_for_start

    mov     #1, pet_x
    mov     #5, pet_y

.game_loop:
    ;;;;; Here there will be a bunch of logic and shiz for the animations, but for now we'll just draw the pet sprite
    call __input
    set1 pcon, 0      ; Wait for an intterupt (Timer counts)
    call __drawpet    ; Draw the pet to the virtual framebuffer
    set1 pcon, 0      ; Wait for another interrupt
    call __movepet
    jmp .game_loop

__input:
    call Get_Input
    ;mov #Button_A, acc
    ;call Check_Button_Pressed
    ;bz 
    ret

__drawpet:
    ;; This is libperspective drawing
    P_Fill_Screen    P_WHITE
    P_Draw_Sprite    pet_spr_addr, pet_x, pet_y
    P_Blit_Screen
    ret

__movepet:
    ret
   

;; Timing stuff in here somewhere

;; Menu logic in here somewhere

.include "lib/libperspective.asm"    ; Kresna's lib perspective for fancy sprite drawing macros
.include "lib/libkcommon.asm"       ; This has some other definitions for buttons and things, 
                                     ;     will check it out later to see if I want to use it	

title1:
    .include sprite "assets/title1.png" ; Waterbear loading up the title screen png
    
pet_spr: 
    .include sprite "assets/baby.png"    ; Waterbear is cool and will import sprites in the format Kresna's LibPerspective uses

    .cnop 0, $200    ; Pad binary to an even number of blocks
