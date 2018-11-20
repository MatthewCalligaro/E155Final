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
	int retVal = 0;
	while(!digitalRead(IRQ)); // Wait for an SDEP.
	while(digitalRead(IRQ)) {
		printf("Received SDEP from master.\n");
		//SPI0CS |= 1 << 7;
		retVal = SPI0FIFO;
//		if(retVal>0) 
		printf("%x\n",retVal);
	//	SPI0CS &= ~(1 << 7);

	}
	printf("Returning.\n");
	//SPI0CS &= ~(1 << 7);
	return retVal;
}

// Send back a "reading" from the "ADC" 
void sendReading(unsigned long long sendit0, unsigned long long sendit1) {
	printf("Writing to SPI.\n");
	// Assert TA = 1 to turn on the SPI. CS[7]
//	SPI0CS |= 1 << 7;
	usleep(100); // Prescribed 100us delay before writing to SPI. 		
	// Send a signal by writing to FIFO. 
	SPI0FIFO = sendit0;
	while(!((SPI0CS >> 16) & 1)); 
	long long save1 = SPI0FIFO;
	SPI0FIFO = sendit1; // TODO bro this isn't how you SPI at all? I'm p sure.
	while(!((SPI0CS >> 16) & 1)); 
	long long save2 = SPI0FIFO;
	printf("%x %x\n", save1, save2);
	// Assert TA = 0 to turn off the SPI. CS[7]
	//SPI0CS &= ~(1 << 7);
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
		//int id = checkFIFO();
	//	printf("id: i%d\n", id);
		SPI0CS |= 1 << 7;	
		sendReading(0x101a01fd41542b42,0x4c45554152545458);
		sendReading(0x100a010c3d010102,0x030405060708090a);
	//	sendReading(0x41542b424c455541525454583d01020304050607080a);
		checkFIFO();
		SPI0CS &= ~(1 << 7);
	}
}
