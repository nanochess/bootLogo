        ;
        ; bootLogo: A Logo implementation in a boot sector.
        ;
        ; by Oscar Toledo G.
        ; https://nanochess.org/
        ;
        ; (c) Copyright 2024 Oscar Toledo G.
        ;
        ; Creation date: Mar/18/2024 5:40pm.
        ; Revision date: Mar/18/2024 8:22pm. Working base commands.
	; Revision date: Mar/18/2024 10:13pm. Working REPEAT command.
	; Revision date: Mar/19/2024. Optimized number decoding. Optimized sin function
	;                             and now it has 7-bit precision. Used extra bytes
	;                             for PU/PD commands.
        ;

        cpu 8086

	;
	; bootLogo is an implementation of the basics of the Logo language.
        ;
	; You have the following commands:
        ;
	; CLEARSCREEN		Clears the screen (only can be used alone)
	; FD 40    		Move the turtle 40 pixels ahead
	; BK 40    		Move the turtle 40 pixels backward.
	; RT 25    		Rotate the turtle 25 degrees clockwise.
	; LT 25    		Rotate the turtle 25 degrees counterclockwise.
	; REPEAT 10 FD 10	Repeat 10 times FD 10
	; REPEAT 10 [FD 10 RT 20]	Repeat 10 times FD 10 RT 20.
	;			Repeat can be nested.
	; PU                    Pen up (turtle doesn't draw).
	; PD                    Pen down (turtle draws).
        ; SETCOLOR 1            Set color for pen.
	; TO name def END       Defines a procedure "name" with definition "def"
	;                       "def" can be any single command, or a list of
	;                       commands between [ and ].
        ; QUIT                  Exit to command line (only .COM version)
	;

    %ifndef com_file
com_file:       equ 0
    %endif

    %ifndef video_mode
video_mode:     equ 4   ; CGA 320x200x4 colors.
    %endif

    %ifndef color1
color1:         equ 1   ; Color for command line.
    %endif

    %ifndef color2
color2:         equ 3   ; Color for drawing.
    %endif

    %if com_file
        org 0x0100
    %else
        org 0x7c00
    %endif

	;
	; Variables are saved just after the program.
	;
ANGLE:  equ $+0x0400	; Current angle of the turtle.
X_COOR: equ $+0x0402    ; Current fractional X-coordinate (9.7)
Y_COOR: equ $+0x0404    ; Current fractional Y-coordinate (9.7)
PEN:	equ $+0x0406    ; Current pen state.
COLOR:	equ $+0x0407	; Current pen color.
NEXT:	equ $+0x0409
PROCS:	equ $+0x040b	; Procedures.

BUFFER: equ $+0x0300	; Buffer for commands.

FRACTION_BITS:  equ 7   ; How many bits has the fraction.
UNIT:   equ 0x01<<FRACTION_BITS ; An unit.

PROC_SIZE:	equ 0x007e	; Maximum size of a procedure.

	;
	; Cold start of bootLogo
	;
start:
        push cs		; Use the code segment...
        push cs
        pop ds		; ...to initialize DS, and...
        pop es		; ...also ES.
        cld		; Clear direction flag.
	call command_clearscreen	; Clear the screen.
	mov ax,PROCS	; Erase all procedures.
	stosw		; Store word.

	;
	; Wait for command.
	;
wait_for_command:
        mov ax,wait_for_command
        push ax

        mov dl,0        ; Point to first column.
        call set_cursor	; CH is zero from here.
        mov al,' '      ; ASCII space character in AL.
        int 0x10        ; Call BIOS.

        call xor_turtle	; Show turtle (1st XOR)

        mov di,BUFFER	; Point to command buffer.
	push di
        mov al,'>'	; Show prompt character.
input_loop:
        mov dx,di	; Get column.
	jmp input_loop3

input_loop2:
        mov al,' '      ; Erase previous character with a space.
	mov dx,di	; Point to previous character.
	dec di		; Buffer pointer gets back.
input_loop3:
        call set_cursor	; CH is zero from here.
        mov cl,1        ; One character.
        int 0x10	; Call BIOS.
        mov ah,0x00	; Wait for key function.
        int 0x16	; Call BIOS.
	cmp al,0x08	; Backspace?
	jz input_loop2	; Yes, jump.
        cmp al,'a'	; Is it lowercase?
        jb .1
        cmp al,'z'+1
        jnb .1		; No, jump.
        sub al,0x20	; Convert to uppercase.
.1:
        stosb		; Save into buffer.
        cmp al,0x0d	; Is it Enter?
        jne input_loop	; No, jump to wait for more keys.

        call xor_turtle	; Remove turtle (2nd XOR)

	pop si		; SI points to start of the command buffer.

	;
	; Run commands alone or in a list.
	;
run_commands:
	call avoid_spaces	; Avoid spaces.
	cmp al,'['		; Is it a list of commands?
	jne run_command		; No, jump to process a single command.
        inc si                  ; Avoid list character '['.
.1:
	call run_command	; Run a single command.
	call avoid_spaces	; Avoid spaces.
	cmp al,']'		; Is it end of list?
	jne .1			; No, keep reading commands.
        inc si                  ; Avoid list character ']'.
	ret

	;
	; Run a command.
	; SI = Pointer to current position in buffer.
	;
run_command:
	call avoid_spaces
	;
	; Search for builtin commands.
	;
        mov di,commands	; DI points to command list.
	mov cx,11	; Eleven commands.
	lodsw		; Read command to execute.
.1:
        scasw           ; Compare with command from table.
        jz found	; Jump if same.
	scasb		; Avoid command address.
	loop .1

	;
	; Search for defined procedures.
	; 
	mov di,PROCS-PROC_SIZE
.7:	lea di,[di+PROC_SIZE]	; Go to next procedure.
	cmp di,[NEXT]	; End of defined procedures?
	je avoid_command	; Yes, jump.
	scasw		; Compare against procedure name.
	jnz .7		; Jump if not the same.
	push si
	mov si,di	; Use definition as source pointer.
	call run_commands	; Run command or commands.
	pop si

	;
	; Avoid extra letters of command.
	;
avoid_command:
	lodsb
	sub al,0x41
	cmp al,0x1a	; Is it a letter?
	jb avoid_command	; Yes, jump.
	dec si

	;
	; Avoid spaces.
	;
avoid_spaces:
	lodsb
	cmp al,0x20	; Is it space?
	je avoid_spaces	; Yes, jump.
	dec si
	ret

	;
	; Command found.
	;
found:  call avoid_command
        xor cx,cx	; Set number to zero.
.3:
        lodsb		; Get a character.
        sub al,'0'	; Is it a number?
        cmp al,10
        jnb .5		; No, jump.
        cbw
	push ax		; ah guaranteed to be zero.
        mov al,10	; cx = cx * 10 + digit
        mul cx
	pop cx
        add cx,ax
        jmp short .3	; Keep reading number.
.5:
	dec si
			; >>> This depends on all commands and command table located 
			;     inside the same 256-byte page <<<
	push di
	pop ax		; To get high byte of address.
	add al,[di]	; Get location (low byte).

	jmp ax

	;
	; Set cursor position.
	; DL = column (0-255).
	;
set_cursor:
	mov cx,40	; 40 columns.
.1:
	sub dl,cl	; Limit column to range 0-39.
	jnb .1
	add dl,cl

	mov dh,21	; Row 21 of the screen.
        mov bx,color1   ; Page (bh) and color (bl).
        mov ah,0x02     ; Set video row, column function.
        int 0x10	; Call BIOS.
	mov ah,0x09
        ret

	;
	; Limit the angle to 0-359 and then to the size of the sin table.
	;
limit:
	mov bx,360	; 360 degrees is the limit.

        cwd		; Sign extend AX to DX:AX
	idiv bx		; Limit it to 360 degrees...
	or dx,dx	; ...by getting modulo.
	jns .1
	add dx,bx	; Make modulo positive.
.1:
        mov ax,128	; Multiply by sin table length.
        mul dx
        div bx		; Divide by 360 degrees.
                        ; Now AX is between 0 and 127.
                        ; (this means AH is zero)
        ;
        ; Get sine
        ;
        test al,64      ; Angle >= 180 degrees?
        pushf
        test al,32      ; Angle 90-179 or 270-359 degrees?
        je .2
        xor al,31       ; Invert bits (reduces table)
.2:
        and al,31       ; Only 90 degrees in table
        mov bx,sin_table
        xlat            ; Get fraction
        popf
        je .3           ; Jump if angle less than 180
        neg ax          ; Else negate result
.3:
        ret		; Return.

	;
	; XOR turtle against the background.
	;
xor_turtle:
        push word [X_COOR]	; Save X-coordinate.
        push word [Y_COOR]	; Save Y-coordinate.
        mov cl,5  		; 5 pixels (depends on CH being zero).
	xor ax,ax
.1:	call advance		; Advance to get turtle nose.
        loop .1			; Until reaching 5 pixels.
				; ch guaranteed to be zero here.
	mov si,turtle_angles	; Table to draw the turtle.
	lodsb			; Get angle for this line.

.2:	mov cl,5
	mul cl
.3:
	mov bx,0x0080		; XOR pixel.
	call draw_pixel2	; Draw in X,Y coordinates.
        loop .3			; Loop to draw the line.
	lodsb			; Get angle for next line.
	test al,al		; Is it zero?
	jnz .2
.4:
        pop word [Y_COOR]	; Restore Y-coordinate.
        pop word [X_COOR]	; Restore X-coordinate.
        ret			; Return.

commands:
	db "CL"
	db command_clearscreen-$
        db "FD"
        db command_fd-$
        db "BK"
        db command_bk-$
        db "RT"
        db command_rt-$
        db "LT"
        db command_lt-$
	db "RE"
	db command_repeat-$
	db "PU"
	db command_pu-$
	db "PD"
	db command_pd-$
	db "SE"
	db command_setcolor-$
	db "TO"
	db command_to-$
        db "QU"
        db command_quit-$

	;
	; CLEARSCREEN command
	;
command_clearscreen:
        mov ax,video_mode
        int 0x10	; Set video mode.

        mov di,ANGLE	; Point to ANGLE variable.
        xor ax,ax	; Zero (north)
        stosw		; Store word.
        mov ah,UNIT*160/256     ; Initial X-coordinate.
        stosw		; Store word.
        mov ah,UNIT*100/256     ; Initial Y-coordinate.
        stosw		; Store word.
	inc ax		; Pen down.
	stosb		; Store byte.
	mov ax,0x0c00+color2	; Color for pen plus Set Pixel function code.
	stosw		; Store word.
	ret

repeat_loop:
        pop si			; Restore start position to re-parse.
	;
	; REPEAT command
	;
command_repeat:
        push si                 ; Save position in buffer.
        push cx                 ; Save repeat count.
	call run_commands
        pop cx                  ; Restore count.
        loop repeat_loop
        pop di                  ; Ignore start position, keep advanced position.
	ret

	;
	; TO command
	;
command_to:
	mov di,[NEXT]		; Pointer to space for next procedure.
	movsw			; Copy procedure name (only 2 letters)
	call avoid_command	; Avoid extra letters.
	mov cx,PROC_SIZE
	rep movsb		; Copy procedure body.
	mov [NEXT],di		; Update pointer.
	ret

	;
	; BK command.
	;
command_bk:
        mov ax,-180	; Reverse direction (-180 degrees)
        db 0xba         ; mov dx, to jump following instruction.
	;
	; FD command.
	;
command_fd:
        xor ax,ax	; Normal direction.
	;
	; Set pixel.
	; 
pixel_set:
	call draw_pixel	; Draw in X,Y coordinates.
        loop pixel_set
        ret

	;
	; LT command.
	;
command_lt:
	neg cx		; Negate angle.
	;
	; RT command.
	;
command_rt:
        add [ANGLE],cx	; Rotate turtle clockwise.
        ret		; Return.

	;
	; PU command
	;
command_pu:
	mov al,0	; Pen up.
	db 0xba		; MOV DX to jump over following instruction

	;
	; PD command
	;
command_pd:
	mov al,1	; Pen down.
	mov [PEN],al	; Set pen status.
	ret		; Return.

	;
	; SETCOLOR command
	;
command_setcolor:
	mov [COLOR],cl	; Save new pen color.
	ret		; Return.

	;
	; QU command.
	;
command_quit:
        int 0x20	; Exit to DOS or bootOS.

	;
        ; Draw pixel in current X,Y integer coordinates.
	;
draw_pixel:
	test byte [PEN],0x01
	jz draw_pixel3
	xor bx,bx	; Set pixel.
draw_pixel2:
	push ax
	push cx
        mov cl,FRACTION_BITS
        mov ax,[X_COOR] ; Get X-coordinate.
        shr ax,cl       ; Remove fractional part.
        mov dx,[Y_COOR] ; Get Y-coordinate.
        shr dx,cl       ; Remove fractional part.
        xchg ax,cx
	mov ax,[COLOR]	; Color in AL and Set Pixel function in AH...
	or al,bl	; ...plus mode (SET or XOR).
	int 0x10
	pop cx
	pop ax
draw_pixel3:
	;
	; Advance turtle in direction.
	; ax = Offset in degrees for angle.
	;
advance:
	push ax
	add ax,[ANGLE]	; Add current angle to offset in ax.
        push ax
        call limit	; Limit angle and get sin.
        add [X_COOR],ax	; Add to X-coordinate.
        pop ax
        add ax,90	; For getting cos.
        call limit
        sub [Y_COOR],ax	; Subtract to Y-coordinate.
	pop ax
        ret

turtle_angles:
	db 210/5
	db 210/5
	db 70/5
	db 110/5
	db 330/5
	db 330/5

	;
        ; sin() function table
        ; It must follow FRACTION_BITS.
	;
sin_table:
	db 0x00, 0x06, 0x0d, 0x13, 0x19, 0x1f, 0x25, 0x2b
	db 0x31, 0x37, 0x3c, 0x42, 0x47, 0x4c, 0x51, 0x56
	db 0x5b, 0x5f, 0x63, 0x67, 0x6a, 0x6e, 0x71, 0x74
	db 0x76, 0x79, 0x7a, 0x7c, 0x7e, 0x7f, 0x7f, 0x80

    %if com_file
    %else
        times 510-($-$$) db 0xff
        db 0x55,0xaa    ; Make it a bootable sector
    %endif


