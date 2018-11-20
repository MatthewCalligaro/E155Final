all: print blue1

print: print.c
	gcc -o print print.c

blue1: blue1.c
	gcc -o blue1 blue1.c `pkg-config --cflags --libs glib-2.0 gio-unix-2.0`
