// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/10/2018
// Summary: Plays and records the digital signal sent by the FPGA 

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <string.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "EasyPIO.h"

////////////////////////////////
//  Constants and Globals
////////////////////////////////

// Program constants
#define VOLUME 16           // volume multiplier
#define BUF_SIZE (1 << 24)  // size of recording buffer
#define INPUT_BITS 11       // bit depth of FPGA signal
#define FLASH_TIME 200      // LED flash time in miliseconds
#define DEBOUNCE_TIME 5     // time in miliseconds to wait for inputs to debounce

// Pins
#define PIN_RECORD 18       // switch to determine play or record mode
#define PIN_START 24        // pushbutton to start/stop play or record
#define PIN_RESET 25        // pushbutton to reset play or record
#define PIN_SAVE 12         // pushbutton to save recording
#define PIN_LED 21          // LED to indicate when playing or recording 
#define NCS 17              // SPI chip select
#define MOSI 22             // SPI master out slave in 
#define SCLK 5              // SPI clock

// WAV constants
#define CHANNELS 1
#define SAMPLE_RATE 48000
#define BIT_DEPTH 16
#define BIT_RATE (SAMPLE_RATE * BIT_DEPTH * CHANNELS / 8)
#define BYTES_PER_SAMPLE (BIT_DEPTH * CHANNELS / 8)

// Global Variables 
short buffer[BUF_SIZE];     // stores samples of the recording
                            // (must be a global variable to prevent segfault due to size)

////////////////////////////////
//  Structs
////////////////////////////////

typedef struct
{
    char fileFormat[4];
    int fileLength;
    char fileType[4];
    char formatHeader[4];
    int formatLength;
    short formatType;
    short channels;
    int sampleRate;
    int bitRate;
    short bytesPerSample;
    short bitDepth;
    char dataHeader[4];
    int dataLength;
} WavHeader;



////////////////////////////////
//  Functions
////////////////////////////////

/**
 * \brief Initialize peripherals
 */
void init()
{
    pioInit();
    pwmInit();

    pinMode(PIN_RECORD, INPUT);
    pinMode(PIN_START, INPUT);
    pinMode(PIN_RESET, INPUT);
    pinMode(PIN_SAVE, INPUT);
    pinMode(PIN_LED, OUTPUT);

    pinMode(NCS, INPUT);
    pinMode(MOSI, INPUT);
    pinMode(SCLK, INPUT);
}

/**
 * \brief Save recorded audio to a .wav file on the website
 *
 * \param buffer        recorded audio samples
 * \param bufferSize    number of audio samples in buffer
 */
void saveRecording(short* buffer, size_t bufferSize)
{
    WavHeader header;
    header.fileFormat[0] = 'R';
    header.fileFormat[1] = 'I';
    header.fileFormat[2] = 'F';
    header.fileFormat[3] = 'F';
    header.fileLength = bufferSize * sizeof(short) + sizeof(WavHeader);
    header.fileType[0] = 'W';
    header.fileType[1] = 'A';
    header.fileType[2] = 'V';
    header.fileType[3] = 'E';
    header.formatHeader[0] = 'f';
    header.formatHeader[1] = 'm';
    header.formatHeader[2] = 't';
    header.formatHeader[3] = ' ';
    header.formatLength = 16;
    header.formatType = 1;
    header.channels = CHANNELS;
    header.sampleRate = SAMPLE_RATE;
    header.bitRate = BIT_RATE;
    header.bytesPerSample = BYTES_PER_SAMPLE;
    header.bitDepth = BIT_DEPTH;
    header.dataHeader[0] = 'd';
    header.dataHeader[1] = 'a';
    header.dataHeader[2] = 't';
    header.dataHeader[3] = 'a';
    header.dataLength = bufferSize * sizeof(short);

    FILE* file = fopen("/var/www/html/recording.wav", "w");
    fwrite(&header, sizeof(WavHeader), 1, file);
    fwrite(buffer, sizeof(short), bufferSize, file);
    fclose(file);
}

/**
 * \brief Load .wav from website into buffer
 *
 * \param buffer        array into which audio samples are loaded
 * 
 * \returns number of samples loaded into buffer 
 */
size_t loadRecording(short* buffer)
{
    size_t samples = 0;
    FILE* file = fopen("/var/www/html/recording.wav", "r");
    if (file != NULL)
    {
        fread(buffer, 1, 44, file); // Read in the header but overwrite it
        samples = fread(buffer, sizeof(short), BUF_SIZE, file);
        fclose(file);
    }

    return samples;
}

/**
 * \brief Flash the LED a given number of times
 *
 * \param numFlashes        number of times to flash LED
 */
void flashLED(int numFlashes)
{
    for (int i = 0; i < numFlashes; ++i)
    {
        digitalWrite(PIN_LED, 1);
        usleep(FLASH_TIME * 1000);
        digitalWrite(PIN_LED, 0);
        usleep(FLASH_TIME * 1000);
    }
}

/**
 * \brief Gets the IP address of the microcontroller
 * 
 * \param buffer to hold IP address in human-readable format
 */
void getIPAddress(char* retIP)
{
    struct ifaddrs* addrs;
    struct ifaddrs* tmp;
    getifaddrs(&addrs);
    tmp = addrs;

    // Iterate interfaces
    while (tmp)
    {
        if (tmp->ifa_addr && tmp->ifa_addr->sa_family == AF_INET)
        {
            struct sockaddr_in *pAddr = (struct sockaddr_in *)tmp->ifa_addr;
            // If the address is not localhost, this is the IP; return it
            if(strcmp(inet_ntoa(pAddr->sin_addr), "127.0.0.1")) {
                strcpy(retIP, inet_ntoa(pAddr->sin_addr));
                freeifaddrs(addrs);
                return;
            }
        }
        tmp = tmp->ifa_next;
    }
    // Did not find an IP
    freeifaddrs(addrs);
    strcpy(retIP, "<yourIPAddress>");
    return;
}

/**
 * \brief Entry point for program
 */
int main()
{
    init();

    // GPIO variables
    int recording = digitalRead(PIN_RECORD);
    int lastRecording = recording;
    int running = 0;
    int start = 0;
    int lastStart = 0;
    int reset = 0;
    int lastReset = 0;
    int save = 0;
    int lastSave = 0;
    size_t inputSamples = 0;

    // PWM variables
    float dut;

    // Recording variables
    size_t recordIndex = loadRecording(buffer);
    size_t playIndex = 0;
    char IPAddress[200];
    getIPAddress(IPAddress);

    // SPI variables
    int curNCS = digitalRead(NCS);
    int lastNCS = curNCS;
    int curSCLK;
    int lastSCLK;
    int reading;
    short input;
    short lastInput;
    int bitsIn;

    printf("starting...\n");

    // One iteration of this loop corresponds to one sample from the FPGA 
    while (1)
    {
        ////////////////////////////////
        //  Handle GPIO
        ////////////////////////////////

        // Allow inputs to debounce before reading
        inputSamples++;
        if (inputSamples / (SAMPLE_RATE / 1000) > DEBOUNCE_TIME)
        {
            recording = digitalRead(PIN_RECORD);
            start = digitalRead(PIN_START);
            reset = digitalRead(PIN_RESET);
            save = digitalRead(PIN_SAVE);
            inputSamples = 0;
        }

        // if switch between play and recording mode, stop playing/recording 
        if (recording != lastRecording)
        {
            running = 0;
        }

        // Handle "start" button
        if (start && !lastStart)
        {
            running = !running;
        }   

        // Handle "reset" button
        if (reset && !lastReset)
        {
            if (recording)
            {
                recordIndex = 0;
            }
            else
            {
                playIndex = 0;
            }
            running = 0;
            flashLED(1);
        }

        // Handle "save" button
        if (save && !lastSave)
        {
            printf("saving...\n");
            saveRecording(buffer, recordIndex);
            printf("your recording is available at http://%s/recording.wav\n", IPAddress);
            flashLED(3);
            running = 0;
        }

        // Update last_ variables so we only trigger on the raising edge of inputs
        lastRecording = recording;
        lastStart = start;
        lastReset = reset; 
        lastSave = save;

        // Turn LED on if playing or recording
        digitalWrite(PIN_LED, running);



        ////////////////////////////////
        //  Calculate next dut
        ////////////////////////////////

        // If in play mode, combine the input with the recording
        if (!recording && running)
        {
            dut = ((float)input + buffer[playIndex]) / (1 << 15);
            playIndex++;

            // If we run out of recording, stop playing
            if (playIndex >= recordIndex)
            {
                running = 0;
                playIndex = 0;
            }
        }
        else
        {
            dut = ((float)input) / (1 << 15);
        }

        // Scale dut so that it is positive
        dut = (dut / 2) + 0.5;    



        ////////////////////////////////
        //  Handle SPI
        ////////////////////////////////

        // Reset SPI variables
        bitsIn = 0;
        lastInput = input;
        input = 0;
        reading = 0;

        // Read from SPI
        while (1)
        {
            curNCS = digitalRead(NCS);

            // NCS is low and we are reading
            if (reading)
            {
                curSCLK = digitalRead(SCLK);

                // Read one bit on the positive edge of SCLK
                if (!lastSCLK && curSCLK)
                {
                    input = (input << 1) + digitalRead(MOSI); 
                    bitsIn++;
                    
                    // Stop reading once we NCS is raised or we read all bits
                    if (curNCS || bitsIn >= INPUT_BITS)
                    {
                        // Convert 11-bit sign-magnitude to 16-bit 2's complement
                        if ((input >> 10) & 0x1)
                        {
                            input = -(input & 0x3FF);
                        }
                        input *= VOLUME;

                        // Don't use the sample if the SPI transfer failed 
                        if (curNCS)
                        {
                            input = lastInput;
                        }

                        // If set to record, add to recording buffer 
                        if (recording && running)
                        {
                            buffer[recordIndex] = input;
                            recordIndex++;

                            if (recordIndex >= BUF_SIZE)
                            {
                                running = 0;
                                recordIndex = 0;
                            }
                        }
                        break;
                    }
                } 
                lastSCLK = curSCLK;
            }

            // We are waiting for NCS to go low
            else if (lastNCS && !curNCS)
            {
                // Set output volume with PWM
                setPWM(SAMPLE_RATE / 2, dut);
                reading = 1;
                curSCLK = digitalRead(SCLK);
                lastSCLK = curSCLK;   
            }
            lastNCS = curNCS;
        }
    }
}
