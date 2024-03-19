     _                 _   _                       
    | |               | | | |                      
    | |__   ___   ___ | |_| |     ___   __ _  ___  
    | '_ \ / _ \ / _ \| __| |    / _ \ / _` |/ _ \ 
    | |_) | (_) | (_) | |_| |___| (_) | (_| | (_) |
    |_.__/ \___/ \___/ \__\_____/\___/ \__, |\___/ 
                                    __/ |      
                                   |___/
### bootLogo interpreter in 512 bytes (boot sector or COM file)

*by Oscar Toledo G. Mar/18/2024*

http://nanochess.org

https://github.com/nanochess

This is a small interpreter of Logo language.

It's compatible with the 8088 processor (the original IBM PC), but it requires a VGA compatible card.

If you want to assemble it, you must download the Netwide Assembler (nasm) from www.nasm.us

Use this command line:

    nasm -f bin bootlogo.asm -Dcom_file=1 -o bootlogo.com
    nasm -f bin bootlogo.asm -Dcom_file=0 -o bootlogo.img

Tested with VirtualBox for Mac OS X running Windows XP running this interpreter, it also works with DosBox and probably with qemu:

    qemu-system-x86_64 -fda bootlogo.img

Enjoy it!

## User's manual

Line entry is done with keyboard, finish the line with Enter.
        
Backspace can be used to correct mistakes.
        
The following commands are implemented:

    CLEARSCREEN

		Clears the screen and returns the turtle to the center,
		and pointing to the north.

		This command can only be used alone.

    FD 40

		Move the turtle 40 pixels ahead.

		Caveat: If you use zero, it will be taken as 65536 pixels.

    BK 40

		Move the turtle 40 pixels backward.
	
		Caveat: If you use zero, it will be taken as 65536 pixels.

    RT 25

		Rotate the turtle 25 degrees clockwise.

    LT 25

		Rotate the turtle 25 degrees counterclockwise.

    REPEAT 10 FD 10

		Repeat 10 times FD 10
	
    REPEAT 10 [FD 10 RT 20]
		
		Repeat 10 times FD 10 RT 20.
		Repeat can be nested.
		If you miss the final ] character then bootLogo will crash.

    QUIT                 

		 Exit to command line (only .COM version)


## Examples

![bootLogo command sequence](example1.png)

![Result of command sequence](example2.png)

## More on this?

Do you would to learn 8086/8088 assembler? Get my book Programming Boot Sector Games containing a 8086/8088 crash course!

Now available from Lulu:

[Paperback book](http://www.lulu.com/shop/oscar-toledo-gutierrez/programming-boot-sector-games/paperback/product-24188564.html)

[Hard-cover book](http://www.lulu.com/shop/oscar-toledo-gutierrez/programming-boot-sector-games/hardcover/product-24188530.html)

[eBook](https://nanochess.org/store.html)

These are some of the example programs documented profusely
in the book:

  * Guess the number.
  * Tic-Tac-Toe game.
  * Text graphics.
  * Mandelbrot set.
  * F-Bird game.
  * Invaders game.
  * Pillman game.
  * Toledo Atomchess.
  * bootBASIC language.

