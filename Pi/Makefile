all: receiver

receiver: receiver.c EasyPIO.h
	gcc -o receiver receiver.c -lm

run: 
	sudo nice -n -20 ./receiver

clean:
	rm receiver