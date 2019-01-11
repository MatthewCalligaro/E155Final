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
#include <sys/time.h>
#include <math.h>
#include "EasyPIO.h"

////////////////////////////////
//  Constants and Globals
////////////////////////////////

// Program constants
#define VOLUME 16           // volume multiplier
#define CLICK_VOLUME 0.5f   // click volume (as a fraction of max volume)
#define BUF_SIZE (1 << 24)  // size of recording buffer (allows for 5 mins 49 secs of recording)
#define INPUT_BITS 11       // bit depth of FPGA signal
#define FLASH_TIME 200      // LED flash time in miliseconds
#define DEBOUNCE_TIME 5     // time in miliseconds to wait for inputs to debounce
#define MAX_MEASURES 16     // maximum measures to use when looping
#define LOOP_COUNTDOWN 4    // number of beats to countdown before recording in loop mode
#define LOOP_DELAY 1000     // time in miliseconds to wait before begining loop coutdown

// Pins
#define PIN_RECORD 18       // switch to determine play or record mode
#define PIN_LOOP 23         // switch to put in loop mode
#define PIN_START 24        // pushbutton to start/stop play or record
#define PIN_RESET 25        // pushbutton to reset play or record
#define PIN_SAVE 12         // pushbutton to save recording
#define PIN_LED 21          // LED to indicate when playing or recording
#define NCS 17              // SPI chip select
#define MOSI 22             // SPI master out slave in
#define SCLK 5              // SPI clock

// WAV constants
#define CHANNELS 1          // number of channels (mono or stereo)
#define SAMPLE_RATE 48000   // samples per second
#define BIT_DEPTH 16        // bits per sample
#define BIT_RATE (SAMPLE_RATE * BIT_DEPTH * CHANNELS / 8)   // bits per second
#define BYTES_PER_SAMPLE (BIT_DEPTH * CHANNELS / 8)         // bytes per sample

// Global Variables
short buffer[BUF_SIZE];     // stores samples of the recording
                            // (must be a global variable to prevent segfault due to size)

////////////////////////////////
//  Structs
////////////////////////////////

/**
 * \brief Struct storing the 44-bit file header of a .wav file
 */
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
    // Initialize peripherals
    pioInit();
    pwmInit();

    // Initialize user interface pins
    pinMode(PIN_RECORD, INPUT);
    pinMode(PIN_START, INPUT);
    pinMode(PIN_RESET, INPUT);
    pinMode(PIN_SAVE, INPUT);
    pinMode(PIN_LED, OUTPUT);

    // Initialize SPI pins
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
    // Fill header with correct data
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

    // Write header and buffer to recording.wav on the website
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

    // If the file on the website exists, read it into buffer
    if (file != NULL)
    {
        // Read in the header (not useful for us)
        fread(buffer, 1, 44, file);

        // Read in the data so that it overwrites the header
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
 * \param buffer  array to hold IP address in human-readable format
 */
void getIPAddress(char* retIP)
{
    struct ifaddrs* addrs;
    struct ifaddrs* tmp;

    // Get all network interfaces as a linked list
    getifaddrs(&addrs);
    tmp = addrs;

    // Iterate through network interfaces searching for the IP address
    while (tmp)
    {
        if (tmp->ifa_addr && tmp->ifa_addr->sa_family == AF_INET)
        {
            struct sockaddr_in *pAddr = (struct sockaddr_in *)tmp->ifa_addr;

            // If the address is not localhost, this is the IP; return it
            if(strcmp(inet_ntoa(pAddr->sin_addr), "127.0.0.1"))
            {
                strcpy(retIP, inet_ntoa(pAddr->sin_addr));
                freeifaddrs(addrs);
                return;
            }
        }
        tmp = tmp->ifa_next;
    }

    // If IP address was not found, return a placeholder so user knows to look it up manually
    freeifaddrs(addrs);
    strcpy(retIP, "<yourIPAddress>");
}

/**
 * \brief Entry point for program
 */
int main()
{
    // Initialize peripherals
    init();

    // GPIO variables
    int recording = digitalRead(PIN_RECORD);    // value of the recording switch
    int lastRecording = recording;              // previous value of the recording switch
    int looping = digitalRead(PIN_LOOP);        // value of the looping switch
    int lastLooping = looping;                  // previous value of the looping switch
    int start = 0;                              // value of the start button
    int lastStart = 0;                          // previous value of the start button
    int reset = 0;                              // value of the reset button
    int lastReset = 0;                          // previous value of the reset button
    int save = 0;                               // value of the save button
    int lastSave = 0;                           // previous value of the save button

    // SPI variables
    int curNCS = digitalRead(NCS);              // value of NCS
    int lastNCS = curNCS;                       // previous value of NCS
    int curSCLK;                                // value of SCLK
    int lastSCLK;                               // previous value of SCLK
    int reading;                                // true when in the middle of an SPI read
    short input;                                // sample received over SPI
    short lastInput;                            // previous sample received over SPI
    int bitsIn;                                 // number of bits received in current SPI read

    // Recording variables
    size_t recordIndex = loadRecording(buffer); // next index in buffer for recording
    size_t playIndex = 0;                       // next index in buffer for playback

    // Looping variables
    size_t measures = 4;                        // length of loop in measures
    size_t beatTime = SAMPLE_RATE / 2;          // number of samples per beat
    size_t beatTimeCounter = 0;                 // counter to keep track of beats
    size_t loopMaxIndex = measures * beatTime * 4;  // maximum index in buffer for the current loop
    size_t loopCountdownCounts = 0;             // counts remaining in countdown before recording
    struct timeval curTime;                     // current time (used for calculating tempo)
    struct timeval lastTime;                    // last time that the tempo button was pressed

    // Other variables
    size_t inputSamples = 0;                    // counter used to debounce input
    int running = 0;                            // whether the current function should run or pause
    float dut;                                  // PMW duty cycle (between 0 and 1)

    // Get device's IP address
    char IPAddress[16];
    getIPAddress(IPAddress);

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
            looping = digitalRead(PIN_LOOP);
            start = digitalRead(PIN_START);
            reset = digitalRead(PIN_RESET);
            save = digitalRead(PIN_SAVE);
            inputSamples = 0;
        }

        // Reset state when changing to and from looping mode
        if (looping != lastLooping)
        {
            running = 0;
            playIndex = 0;
            recordIndex = 0;
        }

        // Linear recording mode (not looping)
        if (!looping)
        {
            // If user switches between play and recording mode, stop playing/recording
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
                playIndex = 0;
                running = 0;
                flashLED(1);
            }

            // Turn on LED if playing or recording
            digitalWrite(PIN_LED, running);
        }

        // Loop mode
        else
        {
            // The "recording" switch place the device in settings mode
            if (recording)
            {
                // Use the start button to set the tempo
                if (start && !lastStart)
                {
                    gettimeofday(&curTime, NULL);
                    beatTime = ((curTime.tv_sec - lastTime.tv_sec) * 1000000
                        + curTime.tv_usec - lastTime.tv_usec) * 48 / 1000;
                    lastTime = curTime;
                    loopMaxIndex = measures * beatTime * 4;
                }

                // Use the reset button to increase the number of measures
                if (reset && !lastReset)
                {
                    measures = (measures >= MAX_MEASURES) ? 1 : measures * 2;
                    flashLED((int)(log2(measures)) + 1);
                    loopMaxIndex = measures * beatTime * 4;
                }

                running = 0;
            }
            else
            {
                // Use the start button to play/pause the loop
                if (start && !lastStart)
                {
                    running = !running;
                }

                // Use the reset button to record a new loop
                // also reset when switching out of settings mode
                if ((reset && !lastReset) || lastRecording)
                {
                    recordIndex = 0;
                    playIndex = 0;
                    beatTimeCounter = 0;
                    loopCountdownCounts = LOOP_COUNTDOWN;
                    running = 1;
                    dut = 0;
                    usleep(LOOP_DELAY * 1000);
                }
            }

            // Count beats if running or in settings mode
            if (running || recording)
            {
                ++beatTimeCounter;
                if (beatTimeCounter >= beatTime)
                {
                    beatTimeCounter = 0;
                    loopCountdownCounts = loopCountdownCounts > 0 ? loopCountdownCounts - 1 : 0;
                }
            }

            // Flash LED to indicate beats when running or in settings mode
            digitalWrite(PIN_LED, (running || recording) && beatTimeCounter < beatTime / 4);
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

        // Update lastX variables so we only trigger on the raising edge of inputs
        lastRecording = recording;
        lastLooping = looping;
        lastStart = start;
        lastReset = reset;
        lastSave = save;



        ////////////////////////////////
        //  Calculate next dut
        ////////////////////////////////

        // Play clicks for the loop countdown
        if (looping && loopCountdownCounts > 0)
        {
            dut = ((float)(beatTime - beatTimeCounter)) / beatTime * CLICK_VOLUME;
        }

        // If in play mode, combine the input with the recording
        else if (running && ((!looping && !recording) || (looping && recordIndex == loopMaxIndex)))
        {
            dut = ((float)input + buffer[playIndex]) / (1 << 15);
            playIndex++;

            // Upon reaching the end of the recording, return to the start
            if (playIndex >= recordIndex)
            {
                playIndex = 0;
                running = looping;  // stop running if not looping
            }
        }
        else
        {
            dut = ((float)input) / (1 << 15);
        }

        // Bias dut so that it is alaways positive
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

                    // Stop reading once NCS is raised or we read all bits
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

                        // If recording, add the sample to the recording buffer
                        if (running && (!looping && recording) || (looping
                            && !loopCountdownCounts && recordIndex < loopMaxIndex))
                        {
                            buffer[recordIndex] = input;
                            recordIndex++;

                            // Stop recording if we fill up the recording buffer
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
                setPWM(SAMPLE_RATE / 2, dut);   // set output volume with PWM
                reading = 1;
                curSCLK = digitalRead(SCLK);
                lastSCLK = curSCLK;
            }
            lastNCS = curNCS;
        }
    }
}
