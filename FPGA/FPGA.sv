// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: Top-level module for FPGA multi-effects 

module FPGA(input logic clk,                        // 40 MHz clock
            input logic reset,                      // hardware reset
            input logic dinAdc,                     // MISO from ADC
            input logic echo,                       // echo pin of ultrasonic sensor
            input logic [4:0] switch,               // hardware DIP switches
            output logic sclkAdc, doutAdc, ncsAdc,  // output for ADC SPI interface (FPGA is master)
            output logic sclkPi, doutPi, ncsPi,     // output for PI SPI interface (FPGA is master)
            output logic trig,                      // trigger pin of ultrasonic sensor
            output logic [7:0] led);                // LED array on the MuddPi board
    
    // Registers
    logic [9:0] counter;        // counter to sample at 48 KHz and generate sclks

    // Wires between modules
    logic [12:0] address;       // address at which we read or write to RAM
    logic WE;                   // write enable for RAM
    logic [9:0] sampleVoltage;  // voltage read from ADC (unsigned)
    logic [10:0] readVoltage;   // voltage read from RAM (sign-magnitude)
    logic [10:0] writeVoltage;  // voltage to write into RAM (sign-magnitude)
    logic [10:0] sendVoltage;   // voltage to send to pi (sign-magnitude)
    logic [9:0] offset;         // voltage bias produced by amplifier (unsigned)
    logic [3:0] intensity;      // inverse of distance detected by ultrasonic sensor

    // Modules
    adc adc1(sclkAdc, reset, !counter[9], 1'b0, dinAdc, doutAdc, ncsAdc, sampleVoltage);
    pi pi1(sclkPi, reset, !counter[9], sendVoltage, doutPi, ncsPi);
    mem mem1(clk, WE, address, writeVoltage, readVoltage);
    calibrate calibrate1(reset, !counter[9], switch, sampleVoltage, offset);
    distance distance1(clk, reset, echo, trig, intensity);
    effects effects1(clk, reset, switch, counter, sampleVoltage, offset, readVoltage, intensity, 
        sendVoltage, writeVoltage, address);

    // Increment counter
    always_ff @(posedge clk, posedge reset) 
        if (reset)  counter <= 1'b0;
        else        counter <= (counter == 10'd832) ? 1'b0 : counter + 1'b1;

    // Assign wires
    assign WE = (counter == 10'd832);           // store writeVoltage on last clk of each cycle
    assign sclkAdc = counter[3];                // ADC's sclk = 2.5 MHz (16 clks)
    assign sclkPi = counter[5];                 // Pi's sclk  = 625 KHz (64 clks)
    assign led = switch[4] ?                    // LEDs display distance sensor if it is on
        {4'b0, intensity} : sendVoltage[9:2];   // otherwise, they display sendVoltage 
endmodule
