// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/10/2018
// Summary:

#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include "EasyPIO.h"

////////////////////////////////
//  Constants
////////////////////////////////

// Resistors:
// LED: 220 ohms
// Switches: 10 kohms

// Program constants
#define RATE 20             // 48KHz ~= 20 microseconds
#define VOLUME 32           // Volume multiplier
#define BUF_SIZE (1 << 21)  // Size of recording buffer
#define ADC_BITS 10         // Bit Depth of ADC
#define FLASH_SPEED 200     // LED flash rate in miliseconds
#define DEBOUNCE_TIME 5     // Time to wait for inputs to debounce in miliseconds

// Pins
#define PIN_RECORD 18   // Switch to determine record or play mode
#define PIN_START 24    // Pushbutton to start/stop play/record
#define PIN_RESET 25    // Pushbutton to reset play/record
#define PIN_SAVE 12     // Pushbutton to save recording
#define PIN_LED 21      // LED to indicate playing or recording 
#define NCS 17
#define MOSI 22
#define SCLK 5

// WAV constants
#define CHANNELS 1
#define SAMPLE_RATE 48000
#define BIT_DEPTH 16
#define BIT_RATE (SAMPLE_RATE * BIT_DEPTH * CHANNELS / 8)
#define BYTES_PER_SAMPLE (BIT_DEPTH * CHANNELS / 8)

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

// TODO: Resolve if it is a unsigned or signed short?
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

size_t loadRecording(short* buffer)
{
    size_t samples = 0;
    FILE* file = fopen("/var/www/html/recording.wav", "r");
    if (file != NULL)
    {
        fread(buffer, 1, 44, file); // Read in the heading but overwrite it
        samples = fread(buffer, sizeof(short), BUF_SIZE, file);
        fclose(file);
    }

    return samples;
}

void flashLED(int numFlashes)
{
    for (int i = 0; i < numFlashes; ++i)
    {
        digitalWrite(PIN_LED, 1);
        usleep(FLASH_SPEED * 1000);
        digitalWrite(PIN_LED, 0);
        usleep(FLASH_SPEED * 1000);
    }
}

int main()
{
    init();

    // Time variables
    struct timeval tv;
    gettimeofday(&tv, NULL);
    long long unsigned int curTime = tv.tv_sec * 1000000 + tv.tv_usec;
    long long unsigned int finishTime = curTime + RATE;

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
    short buffer[BUF_SIZE];
    size_t recordIndex = loadRecording(buffer);
    size_t playIndex = 0;

    // SPI variables
    int curNCS = digitalRead(NCS);
    int lastNCS = curNCS;
    int curSCLK;
    int lastSCLK;
    int inCycle;
    short input;
    short lastInput;
    int bitsIn;

    // Debugging variables 
    int failures = 0;

    printf("starting...\n");
    while (1)
    {
        // Handle GPIO
        inputSamples++;
        if (inputSamples / (SAMPLE_RATE / 1000) > DEBOUNCE_TIME)    // This approach is not gaurenteed to work
        {
            recording = digitalRead(PIN_RECORD);
            start = digitalRead(PIN_START);
            reset = digitalRead(PIN_RESET);
            save = digitalRead(PIN_SAVE);
            inputSamples = 0;
        }

        if (recording != lastRecording)
        {
            running = 0;
        }

        if (start && !lastStart)
        {
            running = !running;
        }   

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
            printf("failures: %d\n", failures);
            flashLED(1);
        }

        if (save && !lastSave)
        {
            printf("saving...\n");
            saveRecording(buffer, recordIndex);
            printf("your recording is available at http://134.173.197.210/recording.wav\n");
            flashLED(3);
            running = 0;
        }

        lastRecording = recording;
        lastStart = start;
        lastReset = reset; 
        lastSave = save;
        digitalWrite(PIN_LED, running);

        // Calculate next dut
        if (!recording && running)
        {
            dut = (input + buffer[playIndex]) / (65535.0);
            playIndex++;

            if (playIndex >= recordIndex)
            {
                running = 0;
                playIndex = 0;
            }
        }
        else
        {
            dut = input / (65535.0);
        }

        // Reset SPI variables
        bitsIn = 0;
        lastInput = input;
        input = 0;
        inCycle = 0;

        // Read from SPI
        while (1)
        {
            curNCS = digitalRead(NCS); // perhaps move this to the two places we need it
            if (inCycle)
            {
                curSCLK = digitalRead(SCLK);
                if (!lastSCLK && curSCLK)
                {
                    input = (input << 1) + digitalRead(MOSI); 
                    bitsIn++;

                    if (curNCS || bitsIn >= ADC_BITS)
                    {
                        input *= VOLUME;
                        if (curNCS)
                        {
                            failures++;
                            input = lastInput;
                        }

                        if (recording && running)
                        {
                            buffer[recordIndex] = input;
                            recordIndex++;
                        }
                        break;
                    }
                } 
                lastSCLK = curSCLK;
            }
            else if (lastNCS && !curNCS)
            {
                setPWM(SAMPLE_RATE / 2, dut);
                inCycle = 1;
                curSCLK = digitalRead(SCLK);
                lastSCLK = curSCLK;   
            }
            lastNCS = curNCS;
        }
    }
}

/*
while (1)
{
    setPWM(SAMPLE_RATE, dut);

    recordIndex++;
    dut = buffer[recordIndex] / 65535.0 * VOLUME;
    // dut = ((counter >> 6) % 2) * VOLUME / 4;
    counter++;

    if (counter % 48000 == 0)
    {
        printf("sec: %d\n", counter / 48000);
    }

    // Wait until the end of this cycle
    while (curTime < finishTime)
    {
        gettimeofday(&tv, NULL);
        curTime = tv.tv_sec * 1000000 + tv.tv_usec;
    }
    finishTime += RATE;
}
*/
