# Guitar Multi-FX and Recording Device
Matthew Calligaro and Giselle Serate\
Fall 2018\
Final Project for Microprocessors Course (E155) at Harvey Mudd College


## Summary
An electric guitarist may require over a thousand dollars of equipment to apply and modulate effects while recording and playing audio through speakers.  This device simplifies this process into a single, affordable design.  It uses an FPGA to digitally apply overdrive, delay, chorus, and distortion effects.  These effects can be modulated by a distance sensor which attaches to the user's guitar.  The processed audio is sent to the microcontroller which can record, play, and loop the signal.  This signal is outputted through a 3.5 mm audio jack, and recordings can be uploaded to the internet as WAV audio files via an Apache webserver.


## User Interface
The user interface consists of a series of pushbuttons, DIP switches, and an LED.  

### FPGA (Audio Effects)
The FPGA receives user input from 5 switches and 1 pushbutton.  Any number of effects can be applied at one time.  

Input | Effect
--- | ---
Switch 0 | Applies overdrive effect
Switch 1 | Applies delay effect
Switch 2 | Applies chorus effect
Switch 3 | Applies distortion effect
Switch 4 | Turns on distance sensor 
Reset button | recalibrates device and sets noise gate

To calibrate the device, turn on all electronics and plug in the guitar.  Without playing any noise, press the **Reset button** to calibrate the default input voltage.  To configure the noise gate, orient the 5 switches with the desired binary value (with switch 4 as the most significant bit) and press the **Reset button**.  A higher value should result in less noise.

### Microcontroller (Recording and Looping)
The Microcontroller receives user input from 2 switches and 1 pushbutton and displays state through an LED.  The two switches are used to set the device's mode.

Loop Switch | Record Switch | Mode
--- | --- | ---
Off | Off | Linear playback
Off | On | Linear record
On | Off | Loop
On | On | Loop settings

In each mode, the pushbuttons have the following effects.

Mode | Play button | Reset button | Save button
--- | --- | --- | ---
Linear playback | play/pause the recording | restart at the beginning of the recording | save the recording to the internet
Linear record | start/stop recording | delete the current recording | save the recording to the internet
Loop | play/pause the current loop | begin recording a new loop | save the loop to the internet
Loop settings | tap to set tempo | increase number of measures | save the loop to the internet 

In each mode, the LED indicates the following information.  In all modes, 3 flashes indicates that the current recording has been successfully saved to the internet. 

1. Linear playback
    * On: currently playing
    * 1 flash: returned to the beginning of the recording
2. Linear record
    * On: currently recording
    * 1 flash: current recording deleted
3. Loop
    * Flashes to indicate tempo
4. Loop settings
    * Flashes to indicate tempo
    * Upon changing the number of measures, flashes `log2(measures) + 1` times

### Instructions for Recording
1. Place the device in **Linear record** mode with the switches.
2. Clear the current recording by pressing the **Reset button**.
3. Begin recording by pressing the **Play button**.  The LED will turn on.  
4. Stop recording by pressing the **Play button**.  The LED will turn off.
5. Place the device in **Linear playback** made with the switches.
6. Play the recording by pressing the **Play button**.  The LED will turn on.
5. To save the recording to the internet, press the **Save button**.  The LED will flash 3 times.

### Instructions for Looping
1. Place the device in **Loop settings** mode with the switches.
2. Tap out the desired tempo on the **Play button**.  The LED will flash the current tempo.
3. By default, a loop consists of 4 measures.  To increase this, press the **Reset button**, which will allow you to select 1, 2, 4, 8, or 16 measures.  The LED will flash `log2(measures) + 1` times.  
4. Place the device in **Loop** mode with the switches.  
5. The device will click 4 times and then begin recording for the set number of measures.  Afterwards, the recorded loop will play indefinitely.  The LED will continue to flash to indicate the tempo.
6. To pause the current loop, press the **Play button**.
7. To record a new loop, press the **Restart button**. 
8. To save the loop to the internet, press the **Save button**.  The LED will flash 3 times.


## Hardware 
### Circuit Diagram
![alt text](https://github.com/MatthewCalligaro/E155Final/blob/master/Reference/CircuitDiagram.jpg "Complete circuit diagram")

### Parts list
Part | Quantity | Purpose | Manufacturer
--- | --- | --- | ---
Raspberry Pi 3 Model B+ | 1 | Microcontroller | Raspberry Pi Foundation
Cyclone IV EP4CE6E22C8N | 1 | FPGA | Altera
LM386N-4 | 1 | Audio Amplifier | National Semiconductor
MCP3002  | 1 | 10-bit ADC | Microchip Technology
HC-SR04 | 1 | Ultrasonic distance sensor | SainSmart
1/4" instrument cable jack | 1 | Receive guitar input | N/A
pushbutton | 4 | FGPA and Microcontroller input | N/A
5 DIP switch | 1 | FPGA input | N/A
2 DIP switch | 1 | Microcontroller input | N/A
10 uF capacitor | 1 | Bypass capacitor | N/A
1 uF capacitor | 1 | Bypass capacitor | N/A
10 kΩ resistor | 11 | Pulldown resistor | N/A
220 Ω resistor | 1 | LED resistor | N/A


## Steps for Setting Up
1. Wire the hardware according to the circuit diagram shown above.
2. Use the `.sv` files in the `FPGA` directory to configure the FPGA, with `FPGA.sv` as the top-level module. 
3. Set up an Apache webserver on the Raspberry Pi.
4. Load the files in the `Pi` directory onto the Raspberry Pi.
5. Navigate to these files and `make`.  
6. Connect your guitar to the device with a 1/4" instrument cable.
7. Connect a speaker or headphones to the 3.5 mm audio jack on the Raspberry Pi.  Keep the speaker turned off.  
8. On the Raspberry Pi, `make run`.  
9. Turn on the speaker.  
