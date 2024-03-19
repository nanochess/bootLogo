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
        ; QUIT                  Exit to command line (only .COM version)
	;

    %ifndef com_file
com_file:       equ 0
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
X_COOR: equ 0xfa02	; Current fractional X-coordinate (10.6)
Y_COOR: equ 0xfa04	; Current fractional Y-coordinate (10.6)
BUFFER: equ 0xfb00	; Buffer for commands.

	;
	; Cold start of bootLogo
	;
start:
	;
	; Command CLEARSCREEN
	;
command_clearscreen:
        cld
        mov ax,0x0013	; VGA 320x200x256 colors mode.
        int 0x10	; Set video mode.

        mov ax,0xa000	; Memory segment where video memory is located.
        mov ds,ax	; Set DS register.
        mov es,ax	; Set ES register.

        mov di,ANGLE	; Point to ANGLE variable.
        xor ax,ax	; Zero (north)
        stosw		; Store.
        mov ah,40	; Initial X-coordinate (160 * 64)
        stosw		; Store.
        mov ah,25	; Initial Y-coordinate (100 * 64)
        stosw		; Store.

	;
	; Wait for command.
	;
wait_for_command:
        xor di,di	; Point to top screen row.
        mov cx,320*8	; 320 pixels and 8 rows.
        xor al,al	; Black pixels.
        rep stosb	; Fill.

        call xor_turtle	; Show turtle (1st XOR)

        mov di,BUFFER	; Point to command buffer.
	push di
        mov al,'>'	; Show prompt character.
input_loop:
        mov dx,di	; Column in dl.
input_loop2:
        push di
        push ax
        mov dh,0	; Row in dh.
        mov bh,0	; Page in bh.
        mov ah,2	; Set video row,column function.
        int 0x10	; Call BIOS.
        pop ax
        mov cx,1	; One character.
        mov bx,0x000f	; Page (bh) and color (bl).
        mov ah,0x09	; Output character function.
        int 0x10	; Call BIOS.
        mov ah,0x00	; Wait for key function.
        int 0x16	; Call BIOS.
        pop di
	cmp al,0x08	; Backspace?
	jne .2		; No, jump.
	mov dx,di	; Point to previous character.
	dec di		; Buffer pointer gets back.
	mov al,0x20	; Erase previous character.
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

	pop di		; DI points to start of the command buffer.
	call run_command	; Run the command.
	jmp wait_for_command	; Wait for another command.

	;
	; Run a command.
	; DI = Pointer to current position in buffer.
	;
run_command:
	call avoid_spaces
        mov si,commands	; SI points to command list.
.1:
        cs lodsw	; Read command from table.
        or ax,ax	; Is it end of table?
        jz avoid_command	; Yes, avoid command.
        cmp ax,[di]	; Compare against entered command.
        jz .2		; Jump if same.
        lodsw		; Avoid calling direction.
        jmp short .1	; Compare another command.

	;
	; Command found.
	;
.2:     call avoid_command
        xor cx,cx	; Set number to zero.
.3:
        mov al,[di]	; Get a character.
        sub al,0x30	; Is it a number?
        jb .5
        cmp al,10
        jnb .5		; No, jump.
        cbw
	push ax		; ah guaranteed to be zero.
        mov al,10	; cx = cx * 10 + digit
        mul cx
	pop cx
        add cx,ax
        inc di		; Go to next character.
        jmp short .3	; Keep reading number.
.5:
	cs jmp [si]	; Call the command.

	;
	; Avoid extra letters of command.
	;
avoid_command:
	mov al,[di]
	and al,0xc0
	cmp al,0x40
	jne avoid_spaces
	inc di
	jmp short avoid_command

	;
	; Avoid spaces.
	;
avoid_spaces:
	mov al,[di]
	inc di
	cmp al,0x20
	je avoid_spaces
	dec di
	ret

	;
	; REPEAT command
	;
command_repeat:
	call avoid_spaces
	cmp al,'['		; Is it a list of commands?
	jne .1			; No, jump.
	inc di			; Avoid list character.
	;
	; Repeat loop.
	;
.1:	push cx			; Save counter of repeats.
	push di			; Save position in buffer.
	push ax
.2:
	call run_command
	pop ax
	push ax
	cmp al,'['
	jne .3
	call avoid_spaces
	cmp al,']'		; Is it end of list?
	jne .2			; No, keep reading commands.
	inc di
.3:
	mov si,di		; Exit pointer.
	pop ax
	pop di			; Restore position in buffer.
	pop cx			; Restore counter.
	loop .1			; Loop.
	mov di,si		; DI points >after< the commands.
	ret

	;
	; FD command.
	;
command_fd:
.1:
        call pixel_set	; Set pixel.
        call advance_straight	; Advance turtle.
        loop .1		; Repeat per pixel count.
        ret		; Return.

	;
	; BK command.
	;
command_bk:
.1:
        call pixel_set	; Set pixel.	
        mov ax,-180	; Opposite direction offset.
        call advance	; Advance turtle.
        loop .1		; Repeat per pixel count.
        ret		; Return.

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
	; QU command.
	;
command_quit:
        int 0x20

	;
	; XOR turtle against the background.
	;
xor_turtle:
        push word [X_COOR]	; Save X-coordinate.
        push word [Y_COOR]	; Save Y-coordinate.
        push word [ANGLE]	; Save current angle.
        xor si,si		; Previous pixel address in SI.
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
        or ax,ax	; Is it negative?
        jns .1		; No, jump.
.0:
        add ax,bx	; Make it positive.
        js .0

.1:     sub ax,bx	; Is it exceeding 360 degrees?
        jnb .1		; Yes, jump to keep reducing.
        add ax,bx	; No, restore value.
        mov dx,64	; Multiply by sin table length.
        mul dx
        div bx		; Divide by 360 degrees.
        mov bx,sin_table
        cs xlat		; Get the fraction.
        cbw		; Extend to 16-bit.
        ret		; Return.

	;
	; Complement pixel and advance straight.
	;
pixel_xor:
	call get_xy
	cmp bx,si	; Same pixel as before?
	jz .2		; Yes, jump to avoid XOR'ing same pixel.
	mov si,bx	; Copy address.
        xor byte [bx],0x0f
.2:
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
	; Set pixel.
	; 
pixel_set:
	call get_xy
        mov byte [bx],0x0f	; Set pixel to white.
        ret

	;
	; Get current X,Y integer coordinates and address for Video RAM.
	;
get_xy:
        push cx
        mov ax,[Y_COOR]	; Get Y-coordinate.
        mov cl,6
        shr ax,cl	; Remove fractional part.
        mov bx,[X_COOR]	; Get X-coordinate.
        shr bx,cl	; Remove fractional part.
        pop cx
        mov dx,320
        mul dx
        add bx,ax
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
	db "CL"
	dw command_clearscreen
        db "QU"
        dw command_quit
        db 0
;       db 0    ; Not needed as first byte of sin_table is zero.       

sin_table:
	db 0x00, 0x06, 0x0c, 0x13, 0x18, 0x1e, 0x24, 0x29
	db 0x2d, 0x31, 0x35, 0x38, 0x3b, 0x3d, 0x3f, 0x40
	db 0x40, 0x40, 0x3f, 0x3d, 0x3b, 0x38, 0x35, 0x31
	db 0x2d, 0x29, 0x24, 0x1e, 0x18, 0x13, 0x0c, 0x06
	db 0x00, 0xfa, 0xf4, 0xed, 0xe8, 0xe2, 0xdc, 0xd7
	db 0xd3, 0xcf, 0xcb, 0xc8, 0xc5, 0xc3, 0xc1, 0xc0
	db 0xc0, 0xc0, 0xc1, 0xc3, 0xc5, 0xc8, 0xcb, 0xcf
	db 0xd3, 0xd7, 0xdc, 0xe2, 0xe8, 0xed, 0xf4, 0xfa

    %if com_file
    %else
        times 510-($-$$) db 0xff
        db 0x55,0xaa    ; Make it a bootable sector
    %endif


