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
p_spr_x         = $17 ; Temp x pos for copyvf
p_spr_y         = $18 ; Temp y pos for copyvf
p_spr_w         = $19 ; temp width for copyvf
p_spr_h         = $20 ; Temp height for copyvf
p_x_times_y     = $21 ; Temp for 2 byte width*height

pet_x           = $13 ; X position of the pet                1 byte
pet_y           = $14 ; Y position of the pet                1 byte
pet_width       = $15 ; Width of pet sprite                  1 byte
pet_height      = $16 ; Height of pet sprite                 1 byte

time            = $37 ; Time for animation of vpet sprite    ? bytes
rseed           = $3c ; RNG seed

v_btn           = $10
v_btn_old       = $11
v_btn_chg       = $12

b_sleep         = $7
b_mod           = $6
b_b             = $5
b_a             = $4
b_r             = $3
b_l             = $2
b_d             = $1
b_u             = $0

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
__goodbye:
    not1    ext, 0
    jmpf    __goodbye

;; VMS File Header
    .org    $200                ; Header starts at $200 for games
    .text   16 "vmupet"         ; 16 bytes for file description
    .text   32 "vmupet32"	; 32 bytes of file description (for dreamcast)
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

    clr1 psw, 1           ; Create random seed using current date/time of system	
    ld $1c
    xor $1d
    set1 psw,1
    st rseed

    set1    ie, 7           ; Reenable interrupts now that hardware is initialized

    call    __pollInput     ; Get the initial button state
    call    __drawtitle     ; Draw and render the title sprite

.wait_for_start:
    call    __pollInput
    bn      v_btn, b_a, .wait_for_start

    ;mov     #1, pet_x
    ;mov     #5, pet_y

.game_loop:
    ;;;;; Here there will be a bunch of logic and shiz for the animations, but for now we'll just draw the pet sprite
    call __clearvf
    call __input
    call __drawpet    ; Draw the pet to the virtual framebuffer
    call __movepet
    call __commitvf
    jmp .game_loop

__drawtitle:
    mov #<title, trl    ; Draw the first part of the title, [trl+trh] point to it
    mov #>title, trh
    inc trl             ; Increment address by 2 since Waterbear includes the
    inc trl             ; dimensions of the image before the data
    call __copytovf     ; Copy image to virtual framebuffer
    call __commitvf     ; Copy virtual framebuffer to real framebuffer
    ret

__drawpet:
    mov #<pet_spr, trl
    mov #>pet_spr, trh
    call __copytovf ; Copy image to virtual framebuffer
    ret

__movepet:
    ret

__input:
    call __pollInput
    ; if we're in pet mode and a is pressed, go to menu here
    ; if we're in menu mode and a is pressed, do something else
    ; if we're in menu mode and b is pressed, go back to pet mode
    ret

__pollInput:
    bp p7, 0, .quit
    push acc
    ld v_btn
    st v_btn_old
    ld p3
    bn acc, 6, .quit
    bn acc, 7, .sleep
.ret_from_sleep:
    xor #$FF
    st v_btn
    xor v_btn_old
    st V_btn_chg
    pop acc
    ret
.quit:
    jmp __goodbye
.sleep:
    mov     #0, t1cnt	       ; Disable Audio
    mov     #0, vccr           ; Turn off LCD
.sleepmore:
    set1    pcon, 0            ; Activate HALT mode again
    bp      p7, 0, .quit       ; This bit goes high if the VMU is docked to a controller
    bp      p3, 7, .sleepmore  ; if SLEEP still isn't pressed
    mov     #$80, vccr         ; Turn the LCD back on
.waitsleepup:
    bn      p3, 7, .waitsleepup
    br      .ret_from_sleep
    

__commitvf:
    push acc        ; Save registers so the application code doesn't need to worry
    push xbnk
    push $2         ; Will use this as pointer for framebuffer
    push vsel
    push vrmad1
    push vrmad2

.begin:
    mov #$80, $2    ; Framebuffer starts at address $180, so we put $80 into $2 for
                    ; Indirect SFR addressing
    xor acc         ; Set acc to zero
    st xbnk         ; Select first half of framebuffer
    st vrmad1       ; Start at first byte in virtual framebuffer
    st vrmad2
    set1 vsel, 4    ; Enable autoincrement address for sequential copy

.loop:
    ld vtrbf        ; Get a byte from Work RAM Virtual Framebuffer
    st @R2          ; Store in real framebuffer
    inc $2          ; Increment to next framebuffer
    ld $2           ; Load value to accumulator for testing
    and #$0F        ; Test if address is divisible by 12
    bne #$0C, .skip ; Since after 2 lines (12 bytes) there are 4 empty bytes need to skip over
    ld $2           ; If address is divisible by 12 then we copied 2 lines
    add #4          ; So add 4 more to skip over the unused bytes
    st $2           ; This is the new address into the framebuffer
    bnz .skip       ; If the address was 0, we have rolled over past 256 and need to
    inc xbnk        ; write to the next bank (since 1 XBNK only contains half the framebuffer)
    mov #$80, $2    ; Reset framebuffer address to point to beginning of next bank
.skip:
    ld vrmad1       ; Get current Work RAM (Virtual Framebuffer) Address
    bne #$C0, .loop ; If we haven't copied the whole virtual framebuffer yet, go back and copy more

    pop vrmad2      ; Restore clobbered registers
    pop vrmad1
    pop vsel
    pop $2
    pop xbnk
    pop acc
    ret

; --------------------------------------------------------------------------------------------------------
; __copytovf - Copy a bitmap from TRH/TRL to Virtual Framebuffer
; Clobbered: Nothing
; --------------------------------------------------------------------------------------------------------
__copytovf:
    push acc        ; Save registers so the application code doesn't need to worry
    push c
    push vsel
    push vrmad1
    push vrmad2

    xor acc         ; Set initial counter to 0
    st c            ; Register C is counter
    st vrmad1       ; Start at first byte in virtual framebuffer
    st vrmad2
    clr1 vsel, 4    ; Make sure autoincrement isn't enabled, we're drawing pixels where we want, so we don't want sequential 

.loop:
    ldc             ; Get a byte from [(trh:trl)+c]
    st vtrbf        ; Store the byte in virtual framebuffer
    inc c           ; Increment counter and check if we copied 6*32 = #$C0 bytes
    bne #$C0, loop  ; If not, then copy more
.done:
    pop vrmad2      ; Restore clobbered registers
    pop vrmad1
    pop vsel
    pop c
    pop acc
    ret

; --------------------------------------------------------------------------------------------------------
; __copy_spr_tovf - Copy a sprite from TRH/TRL to Virtual Framebuffer
; Clobbered: Everything
; Theoretically, I should probably use rolc, rorc for this, but shiro's code works alright, just don't draw too many sprites
; --------------------------------------------------------------------------------------------------------
__copy_spr_tovf:
    push acc        ; Save registers so the application code doesn't need to worry
    push c
    push vsel
    push vrmad1
    push vrmad2

    xor acc         ; Set initial counter to 0
    st c            ; Register C is counter
    st vrmad1       ; Start at first byte in virtual framebuffer
    st vrmad2
    clr1 vsel, 4    ; Make sure autoincrement isn't enabled, we're drawing pixels where we want, so we don't want sequential 

.y_loop:
    ldc             ; Get a byte from [(trh:trl)+c]
    st vtrbf        ; Store the byte in virtual framebuffer
    inc c           ; Increment counter and check if we copied w*h bytes
    push acc        ; Push acc, because we need it for multiplacation
    push b          ; Push b, because we need it for multiplication
    push c          ; Push c, because we need it for multiplication
    ldc             ; read first byte of TRL, should be the width
    push acc        ; put er' on the stack
    ldc             ; read the second byte of TRL, should be the height
    st c            ; store the width in C
    pop acc         ; bring back the old acc
    st b            ; store height in b
    mul             ; this multiples a 16 bit value (made up of acc and c) and multiplies it by b. 
                    ;   It's stored as a 24 bit number stored in b, acc, c in that byte order
    mov 
    bne #$C0, loop  ; If not, then copy more
.x_loop:

.done:
    pop vrmad2      ; Restore clobbered registers
    pop vrmad1
    pop vsel
    pop c
    pop acc
    ret



; -----------------------------------------------------------------------------
; __setvfpixel - Set Virtual Framebuffer Pixel at (x,y)
; Register b = X coordinate
; Register c = Y coordinate
; Clobbered: ACC, B, C, vrmad1/2, vtrbf, Work RAM Registers Modified
; Screen is 48x32 pixels. 1 bpp. 6 bytes horizontal.
; -----------------------------------------------------------------------------    
__setvfpixel:       ; Algorithm: Set ((y*6)+(x/8))th byte's (x%8)-1 pixel
    push b          ; Save X coordinate since B is used for multiplication
    xor acc         ; Clear accumulator
    mov #6, b       ; MUL is kinda reest. {ACC, C} form a 16 bit multiplicand
                    ; which is multiplied with register B to form a 24 bit
                    ; result in {B, ACC, C}
    mul             ; ACC = 0, C = Y coordinate. {B,ACC,C} contains Ycoord*6.
    pop acc         ; Restore X coordinate in accumulator and keep for transfer
    push c          ; Ycoord*6 will never be above 256, so just save lowest 8 bits
    st c            ; Move Xcoord from accumulator to C since it is the dividend
    xor acc         ; Division is also reest. 16-bit divident in {ACC,C}
    mov #8, b       ; 8-bit divisor in Register B
    div             ; Do {ACC,C}/B -> C contains X/8, B contains remainder
    xor acc         ; Clear accumulator just in case
    add c           ; Accumulator = X/8
    pop c           ; Restore multiplication result Ycoord*6
    add c           ; Accumulator is now ((Y*6) + (X/8)), the correct byte in framebuffer
    
    mov #$0, vrmad2 ; VRMAD (9 bit register) holds address of Work RAM (256 byte area)
    st vrmad1       ; which will be accessed through VTRBF (to hold virtual framebuffer)
                    ; Acc holds the byte offset of our virtual pixel group, 
                    ; so set VRMAD1 to that
    clr1 vsel, 4    ; VSEL Bit 4 - If set autoincrement VRMAD on every VRTBF access.
                    ; Disable it, we don't want autoincrement
                    
    ld b            ; Move B (contains the bit offset into the group of pixels)
                    ; to accumulator for comparison
                    
                    ; Because this reest processor doesn't have a way to programatically
                    ; set a bit, we gotta get a little stoopid here and unroll it...
                    
.b0:bne #0, .b1     ; If 0, store in bit 7 (MSB, leftmost) , otherwise check again
    ld vtrbf        ; Load what is already in the virtual framebuffer to acc
    set1 acc, 7     ; Set the pixel
    st vtrbf        ; Store it back into virtual framebuffer
    ret
.b1:bne #1, .b2     ; If 1, store in bit 6 (next bit from MSB), otherwise check again
    ld vtrbf
    set1 acc, 6
    st vtrbf
    ret
.b2:bne #2, .b3     ; Keep doing this ... (Shiro got a bit weird after this. But it's good code, and his words are poetry)
    ld vtrbf
    set1 acc, 5
    st vtrbf
    ret
.b3:bne #3, .b4     ; Getting a little stoopid...
    ld vtrbf
    set1 acc, 4
    st vtrbf
    ret
.b4:bne #4, .b5     ; Rhymeはお辞め　博士に任せ I get STOOPID　涙の出る馬鹿さ加減
    ld vtrbf
    set1 acc, 3
    st vtrbf
    ret
.b5:bne #5, .b6     ;　炎の詩人　止まらん火災　これこそが Worldhights
    ld vtrbf
    set1 acc, 2
    st vtrbf
    ret
.b6:bne #6, .b7     ; 俺の Mind State は Nine-Eight (Like the Dreamcast Release Year)
    ld vtrbf
    set1 acc, 1
    st vtrbf
    ret
.b7:                ; 進むつもり So we don't stop ...
    ld vtrbf
    set1 acc, 0
    st vtrbf
    ret

; -----------------------------------------------------------------------------
; __clearvf - Clear the Virtual Framebuffer
; Clobbered: None
; -----------------------------------------------------------------------------
__clearvf:
    push acc        ; Save registers so the application code doesn't need to worry
    push c
    push vsel
    push vrmad1
    push vrmad2

    xor acc         ; Set initial counter to 0
    st c            ; Register C is counter
    st vrmad1       ; Start at first byte in virtual framebuffer
    st vrmad2
    set1 vsel, 4    ; Enable autoincrement address for sequential copy

.loop:
    xor acc         ; Clear accumulator and use that to clear virtual framebuffer
    st vtrbf        ; Store the byte in virtual framebuffer, and autoincrement
    inc c           ; Increment counter and check if we copied 6*32 = $C0 bytes
    ld c
    bne #$C0, .loop ; If not, then copy more
.done:
    pop vrmad2      ; Restore clobbered registers
    pop vrmad1
    pop vsel
    pop c
    pop acc
    ret

;; Timing stuff in here somewhere

;; Menu logic in here somewhere

; .include "lib/libperspective.asm"    ; Kresna's lib perspective for fancy sprite drawing macros
; .include "lib/libkcommon.asm" ; This has some other definitions for buttons and things,
                                     ;     will check it out later to see if I want to use it	

title:
    .include sprite "assets/title.png" ; Waterbear loading up the title screen png
    
pet_spr:
    .include sprite "assets/baby.png"    ; Waterbear is cool and will import sprites in the format Kresna's LibPerspective uses

    .cnop 0, $200    ; Pad binary to an even number of blocks
