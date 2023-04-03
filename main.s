;;
;; main.s
;;
;; version 0.3.7 // Adding time functionality and pet evolution
;;
;; by <eatcomics>
;;
;; No notes currently
;;

.include "libperspective/sfr.i"

;; Game Variables
;; Some of these should maybe be broken into bits to save memory? I'm not tight for it, but you never know
title_spr_addr      = $8     ; Location of title in memory                   2 bytes
pet_x               = $10    ; X position of the pet                         1 byte
pet_y               = $11    ; Y position of the pet                         1 byte
pet_width           = $12    ; Width of pet sprite                           1 byte
pet_height          = $13    ; Height of pet sprite                          1 byte
pet_dir_horiz       = $14    ; Right = 0, Left = 1                           1 byte
pet_dir_vert        = $15    ; Down = 0, Up = 1                              1 byte
pet_anim_frame      = $16    ; 0 = 1st frame, 1 = 2nd frame                  1 byte
pet_spr_r1_addr     = $17    ; Location of right1 sprite in memory           2 bytes
pet_spr_r2_addr     = $19    ; Location of right2 sprite                     2 bytes
pet_spr_l1_addr     = $21    ; Location of left1 sprite                      2 bytes
pet_spr_l2_addr     = $23    ; Location of left2 sprite                      2 bytes
menu_spr_food_addr  = $25    ; Food menu icon                                2 bytes
menu_spr_2_addr     = $27    ; Placeholder menu 2 sprite                     2 bytes
menu_spr_3_addr     = $29    ; Placeholder menu 3 sprite                     2 bytes

last_time  = $37  ; The stored time                                          1 byte
cur_time   = $38  ; Hold what the actual current time is                     1 byte
rseed      = $3c  ; RNG seed                                                 1 byte
game_mode  = $40  ; Whether we're looking at pet, in menu, or in a minigame  1 byte
menu_sel   = $41  ; The below is dumb, probably, also the name is not good   1 byte
                  ;   all bits 0 = pet mode
                  ;   bit 0 = 1, menu mode
                  ;   bit 1 = 1, walk mode
                  ;   bit 2 = 1, train mode
                  ;   bit 3 = 1, battle
                  ;   bit 4 = 1, sound enable/disable
                  ;   bit 5 = 1, show clock

;; Libkcommon uses these for input
p3_pressed              =       $4      ; 1 byte
p3_last_input           =       $5      ; 1 byte

;; Reset and interrupt vectors
;; I'll comment this in more detail later
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
__goodbye:
    not1    ext, 0
    jmpf    __goodbye

;; VMS File Header
    .org    $200                 ; Header starts at $200 for games
    .text   16 "VMUPet"          ; 16 bytes for file description
    .text   32 "VMUPet for VMU"  ; 32 bytes of file description (for dreamcast)
    .string 16 ""                ; Identifier of application that created the file (we don't need it)

    .include icon "./assets/icon.png" ; Waterbear handles this nicely, nice clean code for us!

;; Finally our game code! Main entry point
    .org   $54B     ; Main starts at $54B if you have one title screen, $680 if two
__main:
    clr1 ie, 7      ; Disable interrupts until hardware is initialized
    mov #$a1, ocr   ; Set up OCR, I don't know if this is what I want or not REVIEW THIS LATER
    mov #$09, mcr   ; Set up Mode Control Register
    mov #$80, vccr  ; Set up LCD Contrast Control Register
    mov #$20, acc
    push acc

    ;; When I'm less lazy I need to comment the below (I don't feel like reading the documentation to make sure I'm accurate)
    mov #$80, sp
    mov #%10000000, ie
    clr1 psw, 3
    clr1 psw, 4
    mov #$05, acc
    push acc

    mov #$80, p1fcr
    clr1 p1, 7
    mov #$80, p1ddr
    clr1 p3int, 0         ; Clear bit 0 in p3int - For interrupts on button press (I may reenable this, and switch to using interrupts for button presses
                          ;  as opposed to what libkcommon is doing. I have yet to decide
    clr1 p1, 7            ; Sets the sound output port

    clr1 psw, 1           ; Create random seed using current date/time of system
    ld $1c                ; load the hours into acc
    xor $1d               ; Xor 1c and 1d, 001C is Minutes, 001D is hours
    set1 psw,1            ; set bit 1 of psw
    st rseed              ; st the result in rseed

    set1   ie, 7                      ; Reenable interrupts now that hardware is initialized
    mov    #%11111111, p3_last_input  ; Prepare p3_last_input before calling Get_Input
    call   Get_Input                  ; Get the initial button state

    ;; Here is where we'll draw the title screen, then we'll wait for a button press and jump to the real game loop
    mov    #<title, acc      ; Load the lower byte of title data from the bank to the accumulator
    st     trl               ; Store that shit in the Table Reference Register lower byte
    st     title_spr_addr    ; Store that in title_spr_addr as well, we'll pass this to LibPerspective to draw
    mov    #>title, acc      ; Now we repeat with the high byte of title
    st     trh               ; Store that shit in the Table Reference Register upper byte
    st     title_spr_addr+1  ; Also, store that high byte in the high byte of title_spr_addr

    ;;; We just do more of the above, but this time for the other sprites
    ;; This is the left facing sprite (frame 1)
    mov    #<pet_spr_l1, acc
    st     trl
    st     pet_spr_l1_addr
    mov    #>pet_spr_l1, acc
    st     trh
    st     pet_spr_l1_addr+1
;;;  The below is for automatically setting the sprite width and height, I will probably be using it later, so left it in
;;;  I believe it's only commented because I was testing for an issue with Libperspective
;    xor    acc
;    ldc
;    st     pet_width
;    mov    #1, acc
;    ldc
;    st     pet_height

    ;; This is the left facing sprite (frame 2)
    mov    #<pet_spr_l2, acc
    st     trl
    st     pet_spr_l2_addr
    mov    #>pet_spr_l2, acc
    st     trh
    st     pet_spr_l2_addr+1

    ;; This is the right facing sprite (frame 1)
    mov    #<pet_spr_r1, acc
    st     trl
    st     pet_spr_r1_addr
    mov    #>pet_spr_r1, acc
    st     trh
    st     pet_spr_r1_addr+1

    ;; This is the right facing sprite (frame 2)
    mov    #<pet_spr_r2, acc
    st     trl
    st     pet_spr_r2_addr
    mov    #>pet_spr_r2, acc
    st     trh
    st     pet_spr_r2_addr+1

    ;; Food menu icon sprite
    mov    #<menu_spr_food, acc
    st     trl
    st     menu_spr_food_addr
    mov    #>menu_spr_food, acc
    st     trh
    st     menu_spr_food_addr+1

    ;; Placeholder second menu item icon
    mov    #<menu_spr_2, acc
    st     trl
    st     menu_spr_2_addr
    mov    #>menu_spr_2, acc
    st     trh
    st     menu_spr_2_addr+1

    ;; Placeholder third menu item icon
    mov    #<menu_spr_3, acc
    st     trl
    st     menu_spr_3_addr
    mov    #>menu_spr_3, acc
    st     trh
    st     menu_spr_3_addr+1


    ;; Actually draw and render the title sprite
    P_Draw_Background    title_spr_addr
    P_Blit_Screen

.wait_for_start:
    call    Get_Input       
    clr1    ocr, 5
    
    set1    ocr, 5
    
    mov     #Button_A, acc        ; Put the A button in the accumulator
    call    Check_Button_Pressed  ; Call Libkcommon Check_Button_Pressed and see if A is pressed
    bz      .wait_for_start       ; If it's not pressed, we just loop until it is

    ;; Initialize some variables
    mov     #0, pet_dir_horiz     ; Set the pet to be moving right  
    mov     #0, pet_dir_vert      ; This is here for moving the pet up and down (currently unused)
    mov     #0, pet_anim_frame    ; Which frame of the animation the pet is on
    mov     #0, pet_x             ; X location of pet on screen
    mov     #12, pet_y            ; Y location of pet on screen
    mov     #0, game_mode         ; Whether we're in the main idle pet screen, or in a menu, or on a walk, etc. 
    mov     #0, menu_sel          ; Which menu selection you're on

.game_loop:
    call __input           ; Check for input
    set1 pcon, 0           ; Wait for an intterupt (Timer counts)
    call __draw            ; Draw things to the virtual framebuffer
    call __move_pet_horiz  ; Make the pet move
    p_blit_screen          ; Draw the screen
    jmp .game_loop         ; Loop!

__input:
    call    Get_Input      ; Libkcommon check input
    push    acc            ; Push the accumulator
    ld      game_mode      ; Store game mode in acc
    bnz     .menu_mode     ; if acc isn't zero, go to menu mode
.pet_mode:
    mov     #Button_A, acc        ; We want to check for the A button
    call    Check_Button_Pressed  ; Actually check it (Libkcommon)
    bnz     .pet_a_pressed        ; If it's pressed, go to .pet_a_pressed
    pop     acc                   ; If it's not pressed, return to the main loop
    ret
.pet_a_pressed:
    set1    game_mode, 0          ; Got to set the game_mode to menu
    pop     acc                   ; Then return to the main loop
    ret
.menu_mode:
    mov     #Button_B, acc        ; While in menu mode, we need to check B
    call    Check_Button_Pressed  ; Actually check it (Libkcommon)
    bnz     .menu_b_pressed       ; If it was call the .menu_b_pressed logic
    mov     #Button_Down, acc     ; Now we want to check if down was pressed
    call    Check_Button_Pressed  ; Actually check it
    bnz     .menu_down_pressed    ; If it was call the .menu_down_pressed logic
    mov     #Button_Up, acc       ; And repeat for up
    call    Check_Button_Pressed
    bnz     .menu_up_pressed
    pop     acc                   ; Nothing pressed, just ret to main loop
    ret
.menu_b_pressed:
    clr1    game_mode, 0          ; B was pressed, so we need to exit menu mode
    pop     acc                   ; Then ret to main loop
    ret
.menu_down_pressed:
    ld      menu_sel              ; Load the current menu selection into acc
    be      #2, .wrap_menu_top    ; If we're at the bottom, we need to wrap to the top
    inc     menu_sel              ; Otherwise, we just increment the menu selection
    pop     acc                   ; Return to the main loop
    ret
.wrap_menu_top:
    clr1    menu_sel, 0           ; Clear both bits of menu_sel
    clr1    menu_sel, 1
    pop     acc                   ; Return to the main loop
    ret
.menu_up_pressed:
    ld      menu_sel              ; Same as down pressed, just in reverse
    be      #0, .wrap_menu_bottom
    dec     menu_sel
    pop     acc
    ret
.wrap_menu_bottom:
    clr1    menu_sel, 0           ; This time, instead of clearing both bits
    set1    menu_sel, 1           ; we just set bit 2, because 2 is the 3rd menu item (0, 1, 2)
    pop     acc                   ; Return to the main loop
    ret

__draw:
    P_Fill_Screen    P_WHITE    ; Fill the screen with white first
    push    acc                 ; Store the acc
    ld      game_mode           ; Check current game mode
    bnz      .menu              ; If game_mode isn't zero, we need to draw the menu
.pet:                           ; If game_mode is zero, we draw the pet
    pop acc
    call    __draw_pet
    ret
.menu:
    pop acc
    call    __draw_menu
    ret

;; The bellow is all just calling Libperspective with the right frames
;; Pretty straightforward (I should probaby make sure I'm pushing and popping everything correctly here, but I'm lazy)
__draw_pet:
    ;; This is libperspective drawing
    ;; Use direction and frame to decide what sprite to draw
    push acc
    ld pet_dir_horiz
    bnz .anim_left1
.anim_right1:
    ld               pet_anim_frame
    bnz              .anim_right2
    mov              #1, pet_anim_frame
    P_Draw_Sprite    pet_spr_r1_addr, pet_x, pet_y
    pop              acc
    ret
.anim_right2:
    mov              #0, pet_anim_frame
    P_Draw_Sprite    pet_spr_r2_addr, pet_x, pet_y
    pop              acc
    ret
.anim_left1:
    ld               pet_anim_frame
    bnz              .anim_left2
    mov              #1, pet_anim_frame
    P_Draw_Sprite    pet_spr_l1_addr, pet_x, pet_y
    pop              acc
    ret
.anim_left2:
    mov              #0, pet_anim_frame
    P_Draw_Sprite    pet_spr_l2_addr, pet_x, pet_y 
    pop              acc
    ret

__draw_menu:
    push   acc
    ld     menu_sel
    bnz    .not_food
.menu_food:
    P_Draw_Sprite_Constant    menu_spr_food_addr, 8, 0
    pop              acc
    ret
.not_food:
    dbnz    acc, .menu3
.menu2:
    P_Draw_Sprite_Constant    menu_spr_2_addr, 8, 0
    pop              acc
    ret
.menu3:
    P_Draw_Sprite_Constant    menu_spr_3_addr, 8, 0
    pop              acc
    ret

__move_pet_horiz:
    ; if pet_dir = 0 inc x, if 1 dec x
    push    acc
    ld      pet_dir_horiz
    bnz     .mv_left
.mv_right:
    inc    pet_x
    ; if pet_x >= 32
    ld     pet_x   
    sub    #32
    bz     .chng_dir_left
    pop    acc
    ret
.chng_dir_left:
    set1    pet_dir_horiz, 0
    pop     acc
    ret
.mv_left:
    dec     pet_x
    ; if pet_x <= 0 
    ld      pet_x   
    bz      .chng_dir_right
    pop     acc
    ret
.chng_dir_right:
    clr1    pet_dir_horiz, 0
    pop     acc
    ret

__move_pet_vert:
    ; if pet_dir = 0 inc y, if 1 dec y
    push acc
    ld pet_dir_vert
    bnz .mv_up
.mv_down:
    inc pet_y
    ; if pet_y >= 16
    ld     pet_y  
    sub    #16
    bz    .chng_dir_up
    pop acc
    ret
.chng_dir_up:
    set1  pet_dir_vert, 0
    pop acc
    ret
.mv_up:
    dec pet_y
    ; if pet_y <= 0 
    ld     pet_y  
    bz    .chng_dir_down
    pop acc
    ret
.chng_dir_down:
    clr1  pet_dir_vert, 0
    pop acc
    ret

.include "libperspective/libperspective.asm"    ; Kresna's lib perspective for fancy sprite drawing macros
.include "libperspective/libkcommon.asm"        ; Kresna's lib for buttons and sleep/mode exit

title:
    .include sprite "assets/title.png" ; Waterbear loading up the title screen png
    
; Waterbear is cool and will import sprites in the format Kresna's LibPerspective uses
pet_spr_l1: 
    .include sprite "assets/baby1.png"
pet_spr_l2:
    .include sprite "assets/baby2.png"
pet_spr_r1:
    .include sprite "assets/baby3.png"
pet_spr_r2:
    .include sprite "assets/baby4.png"
menu_spr_food:
    .include sprite "assets/menu_meat.png"
menu_spr_2:
    .include sprite "assets/menu1.png"
menu_spr_3:
    .include sprite "assets/menu_blank.png"

    .cnop 0, $200    ; Pad binary to an even number of blocks
