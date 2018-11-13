#include "EasyPIO.h"

#define CE0 	8
#define MISO	9
#define MOSI	10
#define SCLK	11

#define IRQ 25

// Check if there is something in the Friend's FIFO from the master. 
// Only allowed to write if we're sent data. 
int checkFIFO() {
	printf("Waiting for SDEP from master...\n");
	while(!digitalRead(IRQ)); // Wait for an SDEP.
	printf("Received SDEP from master.\n");
	SPI0CS |= 1 << 7;
	int retVal = SPI0FIFO;
	SPI0CS &= ~(1 << 7);
	return retVal;
}

// Send back a "reading" from the "ADC" 
void sendReading(long long sendit) {
	printf("Writing to SPI.\n");
	// Assert TA = 1 to turn on the SPI. CS[7]
	SPI0CS |= 1 << 7;
	usleep(100); // Prescribed 100us delay before writing to SPI. 		
	// Send a signal by writing to FIFO. 
	SPI0FIFO = sendit;  
	// Assert TA = 0 to turn off the SPI. CS[7]
	SPI0CS &= ~(1 << 7);
}

int main() {
	pioInit();
	// Set pin type of all four pins to the proper ALT so they can comm over SPI.
	pinMode(CE0, ALT0);
	pinMode(MISO, ALT0);
	pinMode(MOSI, ALT0);
	pinMode(SCLK, ALT0);	
	pinMode(IRQ, INPUT); // We only read from IRQ (to see if a comm avail). 
	// Set clock rate at ~1MHz: clock div=128 if at 250MHz (nearest power of 2). CLK[15:0]
	SPI0CLK = 128;
	while(1) {
		int id = checkFIFO();
		printf("id: %d\n", id);
		sendReading(0x20000a02ffff);
	}
}
