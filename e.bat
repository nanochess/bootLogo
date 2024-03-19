nasm -f bin bootlogo.asm -l bootlogo.lst -o bootlogo.img
nasm -f bin bootlogo.asm -Dcom_file=1 -o bootlogo.com

