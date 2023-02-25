;******************************************************************************
; libkcommon
;******************************************************************************
; Some common functions I use all the time
;******************************************************************************
; Nicer names for button masks
Button_Up               equ     %00000001
Button_Down             equ     %00000010
Button_Left             equ     %00000100
Button_Right            equ     %00001000
Button_A                equ     %00010000
Button_B                equ     %00100000
Button_Mode             equ     %01000000
Button_Sleep            equ     %10000000

Get_Input:
        ;----------------------------------------------------------------------
        ; Get input from P3, compare input to previous P3 input to get buttons
        ; pressed this cycle.
        ;----------------------------------------------------------------------
        ld      p3_last_input
        st      c
        ld      p3
        bn      acc, 6, .quit
        bn      acc, 7, .sleep
.return_from_sleep:
        st      p3_last_input
        xor     #%11111111
        and     c
        xor     #%11111111
        st      p3_pressed
        ret
.quit:
        jmpf    __goodbye
.sleep:
	bn p3, 7, .sleep        ; Wait for SLEEP to be depressed
	mov #0, vccr            ; Blank LCD
.sleepmore:
	set1 pcon,0             ; Enter HALT mode
	bp p7, 0, .quit	        ; Docked?
	bp p3, 7, .sleepmore    ; No SLEEP press yet
	mov #$80, vccr	        ; Reenable LCD
.waitsleepup:
	bn p3, 7, .waitsleepup  ; Wait for SLEEP to be depressed
	br .return_from_sleep   ; I find branching here, instead of back to the top of get input works better  

Check_Button_Pressed:
        ;----------------------------------------------------------------------
        ; Check if a button is pressed, not held, this cycle
        ;----------------------------------------------------------------------
        ; acc = button to check
        ;----------------------------------------------------------------------
        st      c
        ld      p3_pressed
        xor     #%11111111
        and     c
        ret
