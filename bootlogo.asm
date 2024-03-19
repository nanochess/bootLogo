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
	; Variables are saved into the non-visible portion of video RAM.
	;
ANGLE:  equ 0xfa00	; Current angle of the turtle.
X_COOR: equ 0xfa02      ; Current fractional X-coordinate (9.7)
Y_COOR: equ 0xfa04      ; Current fractional Y-coordinate (9.7)
PEN:	equ 0xfa06	; Current pen state.
COLOR:	equ 0xfa07	; Current pen color.

BUFFER: equ 0xfb00	; Buffer for commands.

FRACTION_BITS:  equ 7   ; How many bits has the fraction.
UNIT:   equ 0x01<<FRACTION_BITS ; An unit.

	;
	; Cold start of bootLogo
	;
start:
	;
	; Command CLEARSCREEN
	;
command_clearscreen:
        cld
        mov ax,video_mode
        int 0x10	; Set video mode.

        push cs
        push cs
        pop ds
        pop es

        mov di,ANGLE	; Point to ANGLE variable.
        xor ax,ax	; Zero (north)
        stosw		; Store word.
        mov ah,UNIT*160/256     ; Initial X-coordinate.
        stosw		; Store word.
        mov ah,UNIT*100/256     ; Initial Y-coordinate.
        stosw		; Store word.
	inc ax		; Pen down.
	stosb		; Store byte.
	mov al,color2	; Color for pen.
	stosb		; Store byte.

	;
	; Wait for command.
	;
wait_for_command:
        mov ax,wait_for_command
        push ax

        xor dx,dx       ; Point to command row.
        call set_cursor
        mov ax,0x0920   ; Output character function in AH and space in AL.
        mov cl,40       ; Erase the 40 characters.
        int 0x10        ; Call BIOS.

        call xor_turtle	; Show turtle (1st XOR)

        mov di,BUFFER	; Point to command buffer.
	push di
        mov al,'>'	; Show prompt character.
input_loop:
        mov dx,di	; Column in dl.
input_loop2:
        push di
        push ax
        xchg ax,dx
        mov ah,0
        mov cl,40
        div cl          ; Limit column to 0-39.
        mov dl,ah       ; Column in dl.
        mov dh,0	; Row in dh.
        call set_cursor
        pop ax              
        mov ah,0x09     ; Output character function in AH.
        inc cx          ; One character.
        int 0x10	; Call BIOS.
        mov ah,0x00	; Wait for key function.
        int 0x16	; Call BIOS.
        pop di
	cmp al,0x08	; Backspace?
	jne .2		; No, jump.
	mov dx,di	; Point to previous character.
	dec di		; Buffer pointer gets back.
        mov al,' '      ; Erase previous character with a space.
	jmp input_loop2
.2:
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
	; Run a command.
	; SI = Pointer to current position in buffer.
	;
run_command:
	call avoid_spaces
        mov di,commands	; DI points to command list.
	lodsw		; Read command to execute.
.1:
        scasw           ; Compare with command from table.
        jz .2		; Jump if same.
	scasw		; Avoid command address.
        test byte [di],0xff
        jnz short .1	; Compare another command.
	jmp short avoid_command

	;
	; Command found.
	;
.2:     call avoid_command
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
        jmp [di]        ; Call the command.

	;
	; Avoid extra letters of command.
	;
avoid_command:
	lodsb
	sub al,0x41
	cmp al,0x1a
	jb avoid_command
	dec si

	;
	; Avoid spaces.
	;
avoid_spaces:
	lodsb
	cmp al,0x20
	je avoid_spaces
	dec si
	ret

repeat_loop:
        pop si
	;
	; REPEAT command
	;
command_repeat:
        push si                 ; Save counter of repeats.
        push cx                 ; Save position in buffer.
	call avoid_spaces
	cmp al,'['		; Is it a list of commands?
        pushf
        jne .2                  ; No, jump.
        inc si                  ; Avoid list character '['.
.2:
	call run_command
        popf
        pushf
	jne .3
	call avoid_spaces
	cmp al,']'		; Is it end of list?
	jne .2			; No, keep reading commands.
        inc si                  ; Avoid list character ']'.
.3:
        popf
        pop cx                  ; Restore position in buffer.
        loop repeat_loop
        pop di                  ; Forgottens start position, keeps new.
	ret

	;
	; BK command.
	;
command_bk:
        mov ax,-180
        db 0xba         ; mov dx, to jump following instruction.
	;
	; FD command.
	;
command_fd:
        xor ax,ax
	;
	; Set pixel.
	; 
pixel_set:
        push ax
	test byte [PEN],0xff
	jz .1
        push cx
	call get_xy
        int 0x10
        pop cx
.1:     pop ax
        push ax
        call advance
        pop ax
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
	; XOR turtle against the background.
	;
xor_turtle:
        push word [X_COOR]	; Save X-coordinate.
        push word [Y_COOR]	; Save Y-coordinate.
        push word [ANGLE]	; Save current angle.
        mov cx,5  		; 5 pixels.
.1:	call advance_straight	; Advance to get turtle nose.
        loop .1			; Until reaching 5 pixels.
				; ch guaranteed to be zero here.
        mov ax,-150		; -150 degrees.
        call xor_line10		; Draw line.
        mov ax,-140		; -140 degrees.
        call xor_line		; Draw line.
        mov ax,40		; 40 degrees.
        call xor_line		; Draw line.
        mov ax,-140		; -140 degrees.
        call xor_line10		; Draw line.
        pop word [ANGLE]	; Restore angle.
        pop word [Y_COOR]	; Restore Y-coordinate.
        pop word [X_COOR]	; Restore X-coordinate.
        ret			; Return.

	;
	; XOR a line on the screen.
	; 
xor_line10:
	mov cl,10
xor_line:
        add [ANGLE],ax		; Adjust angle per AX.
.1:
        call pixel_xor		; Draw XOR'ed pixel.
        loop .1			; Loop to draw the line.
	mov cl,5
        ret			; Return.

	;
	; Limit the angle to 0-359 and then to the size of the sin table.
	;
limit:
	mov bx,360

        cwd
	idiv bx		; Limit it to 360 degrees...
	or dx,dx	; ...by getting modulo.
	jns .1
	add dx,bx
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
	; Complement pixel and advance straight.
	;
pixel_xor:
        push cx
	call get_xy
        or al,0x80      ; XOR mode.
        int 0x10
        pop cx
	;
	; Advance turtle in straight direction.
	;
advance_straight:
	xor ax,ax
advance:
	add ax,[ANGLE]	; Add current angle to offset in ax.
        push ax
        call limit	; Limit angle and get sin.
        add [X_COOR],ax	; Add to X-coordinate.
        pop ax
        add ax,90	; For getting cos.
        call limit
        sub [Y_COOR],ax	; Subtract to Y-coordinate.
        ret

	;
        ; Get current X,Y integer coordinates.
	;
get_xy:
        mov cl,FRACTION_BITS
        mov ax,[X_COOR] ; Get X-coordinate.
        shr ax,cl       ; Remove fractional part.
        mov dx,[Y_COOR] ; Get Y-coordinate.
        shr dx,cl       ; Remove fractional part.
        xchg ax,cx
        mov bh,0x00     ; Page.
	mov al,[COLOR]	; Color in AL.
        mov ah,0x0c     ; Set pixel function in AH.
	ret

set_cursor:
        mov bx,color1   ; Page (bh) and color (bl).
        mov ah,0x02     ; Set video row, column function.
        int 0x10	; Call BIOS.
        xor cx,cx
        ret

commands:
        db "FD"
        dw command_fd
        db "BK"
        dw command_bk
        db "RT"
        dw command_rt
        db "LT"
        dw command_lt
	db "RE"
	dw command_repeat
	db "PU"
	dw command_pu
	db "PD"
	dw command_pd
	db "CL"
	dw command_clearscreen
	db "SE"
	dw command_setcolor
        db "QU"
        dw command_quit
	;
	; The end of the commands list is signaled by a zero-byte
	; (provided by the first byte of sin_table)
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


