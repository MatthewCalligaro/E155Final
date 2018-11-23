// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: 

module FPGA(input logic clk, reset,
            input logic dinAdc,
            input logic [3:0] switch,
            output logic sclkAdc, doutAdc, ncsAdc, 
            output logic sclkPi, doutPi, ncsPi,
            output logic [7:0] led);
    
    logic [7:0] sclkGen;    // counter to generate sclks
    logic [9:0] counter;    // counter to sample at 48 KHz
    logic spiStart;         // raises when SPI modules should start the next cycle

    logic [6:0] flangerOffset;  // flanger offset
    logic [4:0] flangerCounter; // counter for when to change flanger offset
    logic flangerDown;          // flanger direction

    logic [12:0] address;   // address to read or write to RAM
    logic [12:0] writeAdr;  // current address we are writing to
    logic WE;

    logic [9:0] readVoltage;    // voltage read from RAM
    logic [9:0] sampleVoltage;  // shift register to read voltage from ADC
    logic [15:0] sumVoltage;    // voltage calculated as effects are applied
    logic [9:0] sendVoltage;    // voltage to send to Pi

    adc adc1(sclkAdc, reset, spiStart, 1'b0, dinAdc, doutAdc, ncsAdc, sampleVoltage);
    pi pi1(sclkPi, reset, spiStart, sendVoltage, doutPi, ncsPi);
    mem mem1(clk, WE, address, sampleVoltage, readVoltage);

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            sclkGen <= 0;
            counter <= 0;
            writeAdr <= 0;
            sendVoltage <= 0;
        end else begin
            case (counter)
                10'h0: begin        // start with sampled voltage
                    sumVoltage <= readVoltage;
                    writeAdr <= writeAdr + 1'b1;
                    address <= writeAdr + 1'b1;
                end
                10'h1: begin        // add digital delay
                    if (switch[1])  sumVoltage <= sumVoltage + readVoltage;
                    address <= writeAdr - 13'd512;
                end 
                10'h2: begin        // add chorus 1
                    if (switch[2])  sumVoltage <= sumVoltage + (readVoltage >> 1);
                    address <= writeAdr - 13'd1024;
                end
                10'h3: begin        // add chorus 2
                    if (switch[2])  sumVoltage <= sumVoltage + (readVoltage >> 1);
                    address <= writeAdr - 13'd2048;
                end
                10'h4: begin        // add chorus 3
                    if (switch[2])  sumVoltage <= sumVoltage + (readVoltage >> 1);
                    address <= writeAdr - flangerOffset;
                end
                10'h5: begin        // add flanger
                    if (switch[3])  sumVoltage <= sumVoltage + readVoltage;
                    address <= writeAdr;
                end
                10'h6: begin        // calculate sendVoltage with saturation
                    if (switch[0])  sendVoltage <= ((sumVoltage << 1) > 10'h3F) ? 10'h3F : {sumVoltage[8:0], 1'b0};
                    else            sendVoltage <= (sumVoltage > 10'h3FF) ? 10'h3FF : sumVoltage[9:0];
                    led <= (sendVoltage > 10'h3FF) ? 8'hFF : sumVoltage[9:2];
                end
            endcase

            // When flangerCounter == 0, increment or decrement flangerOffset
            // When flangerOffset maxes out, change flanger direction
            flangerCounter <= flangerCounter + 1'b1;
            if (flangerCounter == 1'b0) flangerOffset <= flangerOffset + (flangerDown ? 7'h7F : 1'b1);
            flangerDown <= (flangerOffset == 7'h7F) ? !flangerDown : flangerDown;

            sclkGen <= (counter == 10'd832) ? 1'b0 : sclkGen + 1'b1; 
            counter <= (counter == 10'd832) ? 1'b0 : counter + 1'b1;
        end
    end

    assign spiStart = counter < 10'd416;    // Raises when counter == 0
    assign WE = counter == 10'd832;         // Write sampleVoltage on last clk of each cycle
    assign sclkAdc = sclkGen[3];            // ADC sclk = 2.5 MHz (16 clks)
    assign sclkPi = sclkGen[5];             // Pi sclk  = 625 KHz (64 clks)
endmodule
