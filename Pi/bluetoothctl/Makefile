all: main


main: main.c
	gcc -o main main.c display.h display.c agent.h agent.c advertising.h advertising.c gatt.h gatt.c `pkg-config --cflags --libs glib-2.0 gio-unix-2.0`
