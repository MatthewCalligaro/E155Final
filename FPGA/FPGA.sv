// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: Top-level module for FPGA multi-effects 

module FPGA(input logic clk, reset,
            input logic dinAdc, echo,
            input logic [4:0] switch,
            output logic sclkAdc, doutAdc, ncsAdc, 
            output logic sclkPi, doutPi, ncsPi,
            output logic trig,
            output logic [7:0] led);
    
    // Registers
    logic [9:0] counter;    // counter to sample at 48 KHz and generate sclks

    // RAM
    logic [12:0] address;   // address at which we read or write to RAM
    logic WE;               // write enable for RAM

    // Voltages
    logic [9:0] sampleVoltage;      // voltage read from ADC (unsigned)
    logic [10:0] readVoltage;       // voltage read from RAM (sign-magnitude)
    logic [10:0] writeVoltage;      // voltage to write into RAM (sign-magnitude)
    logic [10:0] sendVoltage;       // voltage to send to pi (sign-magnitude)
    logic [9:0] offset;             // voltage bias produced by amplifier (unsigned)

    // Other
    logic [3:0] intensity;  // inverse of distance detected by ultrasonic sensor

    // Modules
    adc adc1(sclkAdc, reset, !counter[9], 1'b0, dinAdc, doutAdc, ncsAdc, sampleVoltage);
    pi pi1(sclkPi, reset, !counter[9], sendVoltage, doutPi, ncsPi);
    mem mem1(clk, WE, address, writeVoltage, readVoltage);
    calibrate calibrate1(reset, !counter[9], sampleVoltage, offset);
    distance distance1(clk, reset, echo, trig, intensity);
    effects effects1(reset, clk, switch, counter, sampleVoltage, offset, readVoltage, intensity, 
        sendVoltage, writeVoltage, address);

    // Increment Counter
    always_ff @(posedge clk, posedge reset) 
        if (reset)  counter <= 1'b0;
        else        counter <= (counter == 10'd832) ? 1'b0 : counter + 1'b1;

    // Assign wires
    assign WE = counter == 10'd832;         // store writeVoltage on last clk of each cycle
    assign sclkAdc = counter[3];            // ADC's sclk = 2.5 MHz (16 clks)
    assign sclkPi = counter[5];             // Pi's sclk  = 625 KHz (64 clks)
    //assign led = sendVoltage[9:2];          // LEDs display sendVoltage magnitude
    assign led = {4'b0, intensity};
endmodule
