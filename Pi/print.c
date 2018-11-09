#include "SPI.h"

int main() {
	pioInit();
	spi0Init();
	// Set pin type of all four pins to the proper ALT so they can comm over SPI.
	pinMode(CE0, ALT0);
	pinMode(MISO, ALT0);
	pinMode(MOSI, ALT0);
	pinMode(SCLK, ALT0);	
	// Set clock rate at ~1MHz: clock div=128 if at 250MHz (nearest power of 2). CLK[15:0]
	*SPI0_CLK = 128;
	while(1) {
		usleep(100000);
		// Assert TA = 1 to turn on the SPI. CS[7]
		*SPI0_CS |= 1 << 7;
		// Send a signal by writing to FIFO. 
		*SPI0_FIFO = 0x7f;  
		// Hang; wait to see if you receive. (Check bit 16 of CS to be 1.)
		while(!((*SPI0_CS >> 16) & 1)); 
		// Read from FIFO and save. 
		char save1 = *SPI0_FIFO;
		// Send a signal by writing to FIFO. 
		*SPI0_FIFO = 0x7f; 
		// Hang; wait to see if you receive. (Check bit 16 of CS to be 1.)
		while(!((*SPI0_CS >> 16) & 1));
		// Read from FIFO and save.
		char save2 = *SPI0_FIFO;

		// Assemble what you read into one number (0d10 bits; fits in 2 bytes). 
		short savefull = ((0x3 & save1) << 4) + save2;
		printf("%#06x\n",savefull);
		// Assert TA = 0 to turn off the SPI. CS[7]
		*SPI0_CS &= ~(1 << 7);
	}
}
