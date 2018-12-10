all: receiver

receiver: receiver.c EasyPIO.h
	gcc -o receiver receiver.c

run: 
	sudo nice -n -20 ./receiver
