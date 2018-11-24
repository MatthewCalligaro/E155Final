all: print blue1 bluez_adapter_connect bluez_adapter_scan

print: print.c
	gcc -o print print.c

blue1: blue1.c
	gcc -o blue1 blue1.c `pkg-config --cflags --libs glib-2.0 gio-unix-2.0`

bluez_adapter_connect: bluez_adapter_connect.c
	gcc `pkg-config --cflags glib-2.0 gio-2.0` -Wall -Wextra -o bluez_adapter_connect bluez_adapter_connect.c `pkg-config --libs glib-2.0 gio-2.0`

bluez_adapter_scan: bluez_adapter_scan.c
	gcc `pkg-config --cflags glib-2.0 gio-2.0` -Wall -Wextra -o bluez_adapter_scan bluez_adapter_scan.c `pkg-config --libs glib-2.0 gio-2.0`

runconn: 
	sudo ./bluez_adapter_connect C2:B8:D4:91:B3
