#include "reg9s12.h"			; include this file in the directory

; LCD Control Pins on Port E
lcd_dat 	equ	PortK   	; LCD data pins (PK5~PK2)
lcd_dir 	equ   	DDRK    	; LCD data direction port
lcd_E   	equ   	$02     	; E signal pin
lcd_RS  	equ   	$01     	; RS signal pin
buzzer	equ	$20

G3	equ	7653	; delay count to generate G3 note (with prescaler=8)
B3	equ	6074	; delay count to generate B3 note 
C4 	equ	5733	; delay count to generate C4 note 
C4S	equ	5412	; delay count to generate C4S (sharp) note
D4 	equ	5108	; delay count to generate D4 note 
E4 	equ	4551	; delay count to generate E4 note 
F4 	equ	4295	; delay count to generate F4 note 
F4S	equ	4054	; delay count to generate F4S note 
G4 	equ	3827	; delay count to generate G4 note 
A4 	equ	3409	; delay count to generate A4 note 
B4F 	equ	3218	; delay count to generate B4F note 
B4	equ	3037	; delay count to generate B4 note 
C5 	equ	2867	; delay count to generate C5 note
C5S	equ	2707 
D5 	equ	2554	; delay count to generate D5 note 
E5 	equ	2275	; delay count to generate E5 note 
F5 	equ	2148	; delay count to generate F5 note 
ZZ	equ	20	; delay count to generate an inaudible sound

notes_1	equ	118	; number of notes in the song1
notes_2	equ	125; number of notes in the song2  
notes_3	equ	61; number of notes in the song3 

	org   	$1000
switch	ds.b	1
delay	ds.w  	1 		; store the delay for OC operation
rep_cnt	ds.b	1		; repeat the song1 this many times
ip	ds.b	1		; remaining notes to be played

	org	$2000		; start of the program
	movb	#$FF, DDRB	; set port B as output for all 8 LEDs
	bset	DDRJ, $02		; set port J bit 1 as output (required by Dragon12+)
	bclr	PTJ, $02		; turn off port J bit 1 to enable LEDs

	bset 	DDRT, buzzer	; set PT5 as the output for the buzzer

	movb	#$FF, DDRP	; set port P as output  
	movb	#$0F, PTP		; turn off 7-segment displays (in Dragon12+)

	movb	#$00, DDRH	; set port H as input for DIP switches

	jsr   	openLCD 		; initialize the LCD
	
	ldx   	#name_		; point to the first line of message
	jsr   	putsLCD		; display in the LCD screen
	jsr	delaying		; generate desired delay
	jsr	delaying		; generate desired delay

main:	
	jsr	clear_lcd		; clear the LCD screen
	jsr   	putsLCD		; display the cleared LCD screen
	jsr	delaying		; generate desired delay
	ldx	#instructs		;setting X as a pointer to the first line of the first set of instructions
	jsr   	putsLCD		; display the first line of the first set of instructions on the first row of the LCD screen
	ldaa	#$C0		; move to the second row of the LCD screen
	jsr	cmd2LCD		;transfer the command to the LCD data pins
	ldx	#instructs_	;setting X as a pointer to the second line of the first set of instructions
	jsr   	putsLCD		; display the second line of the first set of instructions on the second row of the LCD screen
	jsr	wait		;jump to wait until all of the DIP switches are in the up position
cont	jsr	clear_lcd		; clear the LCD screen
	jsr	delaying		; generate desired delay
	ldx	#instructs__	;setting X as a pointer to the second set of instructions
	jsr   	putsLCD		; display the second set of instructions on the first row of the LCD screen
	jsr	shift_display1

wait	brset	PTH,$255,cont
	bra	wait

shift_display1:
loop_shift1:	jsr	cmd2LCD		; jump to cmd2LCD
		jsr	delaying		; generate desired delay
		ldaa	#$18		; shift the display left by one character (moved this to the last line in order to see the first character on both lines); process continued at the beginning of the loop
		brclr	PTH,$01,song1_start	; if DIP switch 1 is in the up position and pushbutton 0 is pressed, the subroutine for the first song is executed
		brclr	PTH,$02,song2_start	; if DIP switch 2 is in the up position and the pushbutton 1 is pressed, the subroutine for the second song is executed
		brclr	PTH,$04,song3_start	; if DIP switch 3 is in the up position and the pushbutton 2 is pressed, the subroutine for the third song is executed
		bra	loop_shift1	; otherwise, go back to the beginning of main

song1_start:
	jsr	clear_lcd		; clear the LCD screen
	jsr	delay_seq		;generate the desired delay (short)
	ldx   	#song1_name	; point to the name of the first song
	jsr   	putsLCD		; display the name on the LCD screen
	lbra	song1_play	;branch to the subroutine that plays the first song

song2_start:
	jsr	clear_lcd		; clear the LCD screen
	jsr	delay_seq		;generate the desired delay (short)
	ldx   	#song2_name	; point to the first part of the name of the first song
	jsr   	putsLCD		; display the part of the name on the first row of the LCD screen
	ldaa	#$C0		; move to the second row of the LCD screen
	jsr	cmd2LCD		;transfer the command to the LCD data pins
	ldx	#song2_name_	;point to the second part of the name of the first song
	jsr   	putsLCD		; display the second part of the name on the second row of the LCD screen
	lbra	song2_play	;branch to the subroutine that plays the second song

song3_start:
	jsr	clear_lcd		; clear the LCD screen
	jsr	delay_seq		;generate the desired delay (short)
	ldx   	#song3_name	; point to the first line of message
	jsr   	putsLCD		; display in the LCD screen
	lbra	song3_play	;branch to the subroutine that plays the second song

song1_play:
	lds   	#$2000		;set the stack pointer at $2000
	movw	#oc5isr,$3E64	; set the interrupt vector
	movb  	#$90,TSCR 	; enable TCNT, fast timer flag clear
	movb  	#$03,TMSK2 	; set main timer prescaler to 8
	bset  	TIOS,$20   	; enable OC5
	movb 	#$04,TCTL1 	; select toggle for OC5 pin action
	ldx	#song1		; use as a pointer to score table
	ldy	#duration1		; points to duration1 table
	movb	#1,rep_cnt		; play the song1 once
	movb	#notes_1,ip	; set up the note counter 
	movw	2,x+,delay		; start with zeroth note 
	ldd	TCNT		; play the first note
	addd	delay		; "
	std	TC5		; "
	bset  	TIE,$20     	; enable OC5 interrupt
	cli                 		;       "

forever	pshy			; save duration1 table pointer in stack
	ldy   	0,y      		; get the duration1 of the current note
	jsr   	d10ms   		; play the note for duration1 x 10ms
	puly			; get the duration1 pointer from stack
	iny			; move the duration1 pointer
	iny			; "
	ldd	2,x+		; get the next note, move pointer
	std	delay		; "
	dec	ip		; if not the last note, play again
	bne	forever		;
	dec	rep_cnt		; check how many times left to play song1
	beq	done		; if not finish playing, re-start from 1st note
	ldx	#song1		; pointers and loop count
	ldy	#duration1		; "
	movb	#notes_1,ip	; "
	movw	0,x,delay		; get the first note delay count
	ldd	TCNT		; play the first note
	addd	#delay		; "
	std	TC5		;"
	bra   	forever		;repeat the loop

done	bclr    	TIE, $20     ; Disable OC5 interrupt
	bclr    	TIOS, $20    ; Disable OC5
	bclr	PTT,buzzer ;turn off buzzer
	lbra	cont	;branch back to the label cont

song2_play:
	lds   	#$2000		;set the stack pointer at $2000
	movw	#oc5isr,$3E64	; set the interrupt vector
	movb  	#$90,TSCR 	; enable TCNT, fast timer flag clear
	movb  	#$03,TMSK2 	; set main timer prescaler to 8
	bset  	TIOS,$20   	; enable OC5
	movb 	#$04,TCTL1 	; select toggle for OC5 pin action
	ldx	#song2		; use as a pointer to score table
	ldy	#duration2		; points to duration2 table
	movb	#1,rep_cnt		; play the song2 once
	movb	#notes_2,ip	; set up the note counter 
	movw	2,x+,delay		; start with zeroth note 
	ldd	TCNT		; play the first note
	addd	delay		; "
	std	TC5		; "
	bset  	TIE,$20     	; enable OC5 interrupt
	cli                 	;       "

forever2 	pshy			; save duration2 table pointer in stack
	ldy   	0,y      		; get the duration2 of the current note
	jsr   	d10ms   		; play the note for duration1 x 10ms
	puly			; get the duration2 pointer from stack
	iny			; move the duration2 pointer
	iny			; "
	ldd	2,x+		; get the next note, move pointer
	std	delay		; "
	dec	ip		; if not the last note, play again
	bne	forever2		;
	dec	rep_cnt		; check how many times left to play song2
	beq	done		; if not finish playing, re-start from 1st note
	ldx	#song2		; pointers and loop count
	ldy	#duration2	; "
	movb	#notes_2,ip	; "
	movw	0,x,delay		; get the first note delay count
	ldd	TCNT		; play the first note
	addd	#delay		; "
	std	TC5		;"
	bra   	forever2		;repeat the loop					

song3_play:
	lds   	#$2000		;set the stack pointer at $2000
	movw	#oc5isr,$3E64	; set the interrupt vector
	movb  	#$90,TSCR 	; enable TCNT, fast timer flag clear
	movb  	#$03,TMSK2 	; set main timer prescaler to 8
	bset  	TIOS,$20   	; enable OC5
	movb 	#$04,TCTL1 	; select toggle for OC5 pin action
	ldx	#song3		; use as a pointer to score table
	ldy	#duration3		; points to duration1 table
	movb	#1,rep_cnt		; play the song1 twice
	movb	#notes_3,ip	; set up the note counter 
	movw	2,x+,delay		; start with zeroth note 
	ldd	TCNT		; play the first note
	addd	delay		; "
	std	TC5		; "
	bset  	TIE,$20     	; enable OC5 interrupt
	cli                 		;       "

forever3 	pshy			; save duration1 table pointer in stack
	ldy   	0,y      		; get the duration1 of the current note
	jsr   	d10ms   		; play the note for ?duration1 x 10ms?
	puly			; get the duration1 pointer from stack
	iny			; move the duration1 pointer
	iny			; "
	ldd	2,x+		; get the next note, move pointer
	std	delay		; "
	dec	ip		; if not the last note, play again
	bne	forever3		;
	dec	rep_cnt		; check how many times left to play song1
	beq	done_		; if not finish playing, re-start from 1st note
	ldx	#song3		; pointers and loop count
	ldy	#duration3		; "
	movb	#notes_3,ip	; "
	movw	0,x,delay		; get the first note delay count
	ldd	TCNT		; play the first note
	addd	#delay		; "
	std	TC5		;"
	bra   	forever3		;repeat the loop		

oc5isr 	ldd   	TC5		; restart the OC function
	addd  	delay
	std   	TC5
	rti

done_	lbra	done

; Create a time delay of 10ms Y times (prescaler =8)
d10ms	bset	TIOS,$01		; enable OC0
	ldd 	TCNT
again1	addd	#30000		; start an output-compare operation
	std	TC0		; for 10 ms time delay
	brclr	TFLG1,$01,*	;"
	ldd	TC0		;"
	dbne	y,again1		;"
	rts			;return to subroutine call

; Utility subroutines

clear_lcd:
		ldaa		#$01  ; Clear display command
		jsr		cmd2LCD ;transfer command to the LCD data pins
		RTS

cmd2LCD ; actual
	psha			; save the command in stack
	bclr  	lcd_dat, lcd_RS	; set RS=0 for IR => PTK0=0
	bset  	lcd_dat, lcd_E 	; set E=1 => PTK=1
	anda  	#$F0    		; clear the lower 4 bits of the command
	lsra 			; shift the upper 4 bits to PTK5-2 to the 
	lsra            		; LCD data pins
	oraa  	#$02  		; maintain RS=0 & E=1 after LSRA
	staa  	lcd_dat 		; send the content of PTK to IR 
	nop			; delay for signal stability
	nop			; 	"	
	nop			;	"	
	bclr  	lcd_dat,lcd_E   	; set E=0 to complete the transfer

	pula			; retrieve the LCD command from stack
	anda  	#$0F    		; clear the lower four bits of the command
	lsla            		; shift the lower 4 bits to PTK5-2 to the
	lsla            		; LCD data pins
	bset  	lcd_dat, lcd_E 	; set E=1 => PTK=1
	oraa  	#$02  		; maintain E=1 to PTK1 after LSLA
	staa  	lcd_dat 		; send the content of PTK to IR
	nop			; delay for signal stability
	nop			;	"
	nop			;	"
	bclr  	lcd_dat,lcd_E	; set E=0 to complete the transfer

	ldy	#1		; adding this delay will complete the internal
	jsr	delay50us		; operation for most instructions
	rts

openLCD movb	#$FF,lcd_dir	; configure Port K for output
	ldy   	#2		; wait for LCD to be ready
	jsr   	delay100ms	;	"
	ldaa  	#$28           	 ; set 4-bit data, 2-line display, 5 × 8 font
	jsr   	cmd2lcd         ;       "	
	ldaa  	#$04            ; turn on display and cursor, and blinking off
	jsr   	cmd2lcd         ;       "
	ldaa  	#$06             ; move cursor right (entry mode set instruction)
	jsr   	cmd2lcd         ;       "
	ldaa  	#$01            ; clear display screen and return to home position
	jsr   	cmd2lcd         ;       "
	ldy   	#2              ; wait until clear display command is complete
	jsr   	delay1ms   	;       "
	rts 	

; The character to be output is in accumulator A.
putcLCD	psha                    ; save a copy of the chasracter
	bset  	lcd_dat,lcd_RS	; set RS=1 for data register => PK0=1
	bset  	lcd_dat,lcd_E  	; set E=1 => PTK=1
	anda  	#$F0            ; clear the lower 4 bits of the character
	lsra           		; shift the upper 4 bits to PTK5-2 to the
	lsra            	; LCD data pins
	oraa  	#$03            ; maintain RS=1 & E=1 after LSRA
	staa  	lcd_dat        	; send the content of PTK to DR
	nop                     ; delay for signal stability
	nop                     ;      "
	nop                     ;      "
	bclr  	lcd_dat,lcd_E   ; set E=0 to complete the transfer

	pula			; retrieve the character from the stack
	anda  	#$0F    	; clear the upper 4 bits of the character
	lsla            	; shift the lower 4 bits to PTK5-2 to the
	lsla            	; LCD data pins
	bset  	lcd_dat,lcd_E   ; set E=1 => PTK=1
	oraa  	#$03           	 ; maintain RS=1 & E=1 after LSLA
	staa  	lcd_dat		; send the content of PTK to DR
	nop			; delay for signal stability
	nop			;	"
	nop			;	"
	bclr  	lcd_dat,lcd_E   	; set E=0 to complete the transfer

	ldy	#1		; wait until the write operation is complete
	jsr	delay50us		; delay for 50us
	rts			; return to subroutine call


putsLCD		ldaa  	1,X+   		; get one character from the string
		beq   	donePS		; reach NULL character?
		jsr   	putcLCD		; jump to subroutine putcLCD to display character
		bra   	putsLCD		; branch back to beginning of putsLCD
donePS		rts 			; return to subroutine call if finished displaying message


; additional delay loop to slow down the display shift 
delay_seq		ldab	#$01		; generating the delay
delay1		ldx	#$FFFF		;	"	
delay2		dbne	x,delay2		;	"	
		dbne	b,delay1		;	"	
		rts			; return to subroutine call

; delay loop to transition between messages
delaying		ldab	#$80		; generating the delay
delaying1		ldx	#$FFFF		;	"	
delaying2		dbne	x,delaying2		;	"	
		dbne	b,delaying1		;	"	
		rts			; return to subroutine call

delay1ms 		movb	#$90,TSCR	; enable TCNT & fast flags clear
		movb	#$06,TMSK2 	; configure prescale factor to 64
		bset	TIOS,$01		; enable OC0
		ldd 	TCNT		;	"
again0		addd	#375		; start an output compare operation
		std	TC0		; with 50 ms time delay
wait_lp0		brclr	TFLG1,$01,wait_lp0	;	"
		ldd	TC0		;	"
		dbne	y,again0		;	"
		rts			;	"
	
delay100ms 	movb	#$90,TSCR	; enable TCNT & fast flags clear
		movb	#$06,TMSK2 	; configure prescale factor to 64
		bset	TIOS,$01		; enable OC0
		ldd 	TCNT		;	"
again2		addd	#37500		; start an output compare operation
		std	TC0		; with 50 ms time delay
wait_lp1		brclr	TFLG1,$01,wait_lp1	;	"
		ldd	TC0		;	"
		dbne	y,again2		;	"
		rts			;	"

delay50us 		movb	#$90,TSCR	; enable TCNT & fast flags clear
		movb	#$06,TMSK2 	; configure prescale factor to 64
		bset	TIOS,$01		; enable OC0
		ldd 	TCNT		;	"
again3		addd	#15		; start an output compare operation
		std	TC0		; with 50 ms time delay
wait_lp2		brclr	TFLG1,$01,wait_lp2	;	"
		ldd	TC0		;	"
		dbne	y,again3		;	"
		rts			;	"


; Messages
name_		dc.b	"Nicole Adelson",0
instructs		dc.b	"Push up DIP",0
instructs_		dc.b	"switches",0
instructs__	dc.b	"Press PH0, PH1, or PH2 to play!",0
song1_name	dc.b	"National Anthem",0
song2_name	dc.b	"The Angry Birds",0
song2_name_	dc.b	"Theme Song",0  
song3_name	dc.b	"The Dreidel Song",0

; store the notes of the whole song1
song1	dc.w	D4,B3,G3,B3,D4,G4,B4,A4,G4,B3,C4S
	dc.w	D4,ZZ,D4,ZZ,D4,B4,A4,G4,F4S,E4,F4S,G4,ZZ,G4,D4,B3,G3
	dc.w	D4,B3,G3,B3,D4,G4,B4,A4,G4,B3,C4S,D4,ZZ,D4,ZZ,D4
	dc.w	B4,A4,G4,F4S,E4,F4S,G4,ZZ,G4,D4,B3,G3,B4,ZZ,B4
	dc.w	B4,C5,D5,ZZ,D5,C5,B4,A4,B4,C5,ZZ,C5,ZZ,C5,B4,A4,G4
	dc.w	F4S,E4,F4S,G4,B3,C4S,D4,ZZ,D4,G4,ZZ,G4,ZZ,G4,F4S
	dc.w	E4,ZZ,E4,ZZ,E4,A4,C5,B4,A4,G4,ZZ,G4,F4S,D4,ZZ,D4
	dc.w	G4,A4,B4,C5,D5,G4,A4,B4,C5,A4,G4

; each number is multiplied by 10 ms to give the duration of the corresponding note
duration1	dc.w	30,10,40,40,40,80,30,10,40,40,40
	dc.w	80,3,20,3,20,60,20,40,80,20,20,40,3,40,40,40,40
	dc.w	30,10,40,40,40,80,30,10,40,40,40,80,3,20,3,20
	dc.w	60,20,40,80,20,20,40,3,40,40,40,40,20,3,20
	dc.w	40,40,40,3,80,20,20,40,40,40,3,80,3,40,60,20,40
	dc.w	80,20,20,40,40,40,80,3,40,40,3,40,3,20,20
	dc.w	40,3,40,3,40,40,20,20,20,20,3,40,40,20,3,20
	dc.w	60,20,20,20,80,20,20,60,20,40,80

; store the notes of the whole song2
song2	dc.w	E4,F4S,G4,ZZ,E4,ZZ,B4,ZZ,E4,F4S,G4,ZZ,B4,ZZ,B4,ZZ
	dc.w	B4,C5,B4,A4,G4,ZZ,G4,F4S,E4,ZZ,E4,F4S
	dc.w	G4,E4,ZZ,G4,A4,B4,G4,ZZ,B4,C5S,D5,C5S
	dc.w	D5,C5S,D5,E5,D5,C5S,B4,E4,F4S
	dc.w	G4,ZZ,E4,ZZ,G4,A4,B4,ZZ,G4,ZZ,B4,C5S,D5,C5S
	dc.w	D5,C5S,D5,E5,D5,C5S,B4,ZZ,B4,C5S
	dc.w	D5,ZZ,D5,ZZ,D5,ZZ,D5,ZZ,D5,E5,D5,C5S,D5,B4,C5S
	dc.w	D5,ZZ,D5,C5S,ZZ,C5S,A4,E4,B4,ZZ,B4,ZZ,B4,C5S
	dc.w	D5,ZZ,D5,ZZ,D5,ZZ,D5,ZZ,D5,E5,D5,C5S,D5,B4,C5S
	dc.w	D5,ZZ,D5,C5S,ZZ,C5S,A4,E4
		; 8

; each number is multiplied by 10 ms to give the duration of the corresponding note
duration2	dc.w	20,20,20,10,20,10,20,10,20,20,20,10,20,10,25,10
	dc.w	20,20,20,20,30,3,20,20,40,35,20,20
	dc.w	30,30,35,20,20,30,30,35,20,20,20,20
	dc.w	20,20,20,20,20,20,60,20,20
	dc.w	20,10,20,35,20,20,20,10,20,35,20,20,20,20
	dc.w	20,20,20,20,20,20,60,3,20,20
	dc.w	30,3,30,3,30,3,30,3,20,20,20,20,30,20,20
	dc.w	30,3,30,30,3,20,20,30,30,3,30,3,20,20
	dc.w	30,3,30,3,30,3,30,3,20,20,20,20,30,20,20
	dc.w	30,3,30,30,3,20,20,40

song3	dc.w	D4,ZZ,D4,E4,ZZ,E4,F4S,D4,ZZ,F4S,A4,ZZ,A4,G4,F4S,E4,ZZ
	dc.w	E4,ZZ,E4,F4S,ZZ,F4S,G4,E4,ZZ,E4,A4,G4,F4S,E4,F4S,ZZ
	dc.w	A4,F4S,A4,F4S,A4,F4S,ZZ,F4S,A4,ZZ,A4,G4,F4S,E4,ZZ
	dc.w	G4,E4,G4,E4,G4,E4,ZZ,E4,A4,G4,F4S,E4,D4

; each number is multiplied by 10 ms to give the duration of the corresponding note
duration3	dc.w	30,3,30,30,3,30,30,30,30,30,30,3,30,30,30,30,60
	dc.w	30,3,30,30,3,30,30,30,30,30,30,30,30,30,30,60
	dc.w	30,30,30,30,30,30,30,30,30,3,30,30,30,30,60
	dc.w	30,30,30,30,30,30,30,30,30,30,30,30,30	

	end