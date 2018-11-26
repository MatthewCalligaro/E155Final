// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: Top-level module for FPGA multi-effects 

module FPGA(input logic clk, reset,
            input logic dinAdc,
            input logic [3:0] switch,
            output logic sclkAdc, doutAdc, ncsAdc, 
            output logic sclkPi, doutPi, ncsPi,
            output logic [7:0] led);
    
    // Clock and SPI
    logic [9:0] counter;    // counter to sample at 48 KHz and generate sclks
    logic spiStart;         // raises when SPI modules should start the next cycle

    // Calibration
    logic calibrate;                    // indicates that we are in calibration mode
    logic [31:0] offsetSum;             // used to calculate the average voltage during calibration period
    logic [12:0] calibrationSamples;    // the number of samples taken so far during the calibration period
    logic [9:0] offset;                 // voltage bias produced by amplifier

    // RAM
    logic [12:0] address;   // address at which we read or write to RAM
    logic [12:0] writeAdr;  // current address we are writing to
    logic increaseAdr;      // indicates whether we should increase writeAdr this cycle
    logic WE;               // write enable for RAM

    // Voltages
    logic [9:0] sampleVoltage;      // shift register to read voltage from ADC (unsigned)
    logic [10:0] readVoltage;       // voltage read from RAM (sign-magnitude)
    logic [10:0] writeVoltage;      // voltage sampled during last cycle to store in RAM (sign-magnitude)
    logic [15:0] sumVoltage;        // voltage calculated as effects are applied (2's complement)
    logic [9:0] sendVoltageMag;     // magnitude of voltage to send to pi
    logic sendVoltageSign;          // sign of voltage to send to pi

    // Modules
    adc adc1(sclkAdc, reset, spiStart, 1'b0, dinAdc, doutAdc, ncsAdc, sampleVoltage);
    pi pi1(sclkPi, reset, spiStart, {sendVoltageSign, sendVoltageMag}, doutPi, ncsPi);
    mem mem1(clk, WE, address, writeVoltage, readVoltage);

    // Registers
    always_ff @(posedge clk, posedge reset) begin
        // on reset, reset relevant registers and enter calibration mode
        if (reset) begin;
            counter <= 0;
            writeAdr <= 0;
            increaseAdr <= 0;
            calibrate <= 1'b1;
            offsetSum <= 0;
            calibrationSamples <= 0;
        end 
        
        // in calibration mode, calculate average voltage bias produced by amplifier 
        else if (calibrate) begin
            if (counter == 0) begin
                // add the next calibration sample to the sum
                offsetSum <= offsetSum + sampleVoltage;
                calibrationSamples <= calibrationSamples + 1'b1;
                led <= calibrationSamples[12:5];

                // once we have collected 4096 samples, calculate the offset and end calibration
                if (calibrationSamples == 13'h1000) begin
                    offset <= offsetSum[21:12];
                    calibrate <= 1'b0;
                end
            end 
        end

        // otherwise, sample, apply effects, and send to the Pi
        else begin
            case (counter)
                10'h0: begin        // start with previous sampled voltage
                    sumVoltage <= sampleVoltage;
                    writeAdr <= writeAdr + increaseAdr;
                    increaseAdr <= !increaseAdr;
                end
                10'h1: begin        // factor in offset
                    sumVoltage <= sumVoltage - offset;
                    writeVoltage <= (sampleVoltage < offset) ? {1'b1, offset - sampleVoltage} : {1'b0, sampleVoltage - offset};
                end
                10'h2: begin        // reduce noise with a gate
                    if (writeVoltage[9:0] < 8'h7) begin
                        writeVoltage <= 1'b0;
                        sumVoltage <= 1'b0;
                    end 
                    address <= writeAdr + 1'b1;
                end
                10'h3: begin        // add digital delay
                    if (switch[1])  sumVoltage <= (readVoltage[10] ? (sumVoltage - readVoltage[9:0]) : (sumVoltage + readVoltage[9:0]));
                    address <= writeAdr - 13'h200;
                end 
                10'h4: begin        // add chorus 1
                    if (switch[2])  sumVoltage <= (readVoltage[10] ? (sumVoltage - readVoltage[9:1]) : (sumVoltage + readVoltage[9:1]));
                    address <= writeAdr - 13'h300;
                end
                10'h5: begin        // add chorus 2
                    if (switch[2])  sumVoltage <= (readVoltage[10] ? (sumVoltage - readVoltage[9:1]) : (sumVoltage + readVoltage[9:1]));
                    address <= writeAdr - 13'h400;
                end
                10'h6: begin        // add chorus 3
                    if (switch[2])  sumVoltage <= (readVoltage[10] ? (sumVoltage - readVoltage[9:1]) : (sumVoltage + readVoltage[9:1]));
                    address <= writeAdr;
                end
                10'h7: begin        // calculate sendVoltageSign
                    sendVoltageSign <= sumVoltage[15];
                    sumVoltage <= sumVoltage[15] ? -sumVoltage : sumVoltage; 
                end
                10'h8: begin        // add overdrive to sendVoltageMag with saturation
                    if (switch[0])  sendVoltageMag <= (sumVoltage > 16'h7F) ? 10'hFF : {sumVoltage[8:0], 1'b0};                   
                    else            sendVoltageMag <= (sumVoltage > 16'h3FF) ? 10'h3FF : sumVoltage[9:0];
                end
                10'h9: begin        // add solo effect by inverting sendVoltageMag
                    if (switch[3])  sendVoltageMag <= (sendVoltageMag > 4'hC) ? (-sendVoltageMag) >> 1 : 1'b0;
                end 
                10'h10: begin        // update LEDs
                    led <= sendVoltageMag[9:2];
                end
            endcase

            // update counter
            counter <= (counter == 10'd832) ? 1'b0 : counter + 1'b1;
        end
    end

    assign spiStart = counter < 10'd416;    // raises when counter == 0
    assign WE = counter == 10'd832;         // store writeVoltage on last clk of each cycle
    assign sclkAdc = counter[3];            // ADC's sclk = 2.5 MHz (16 clks)
    assign sclkPi = counter[5];             // Pi's sclk  = 625 KHz (64 clks)
endmodule
