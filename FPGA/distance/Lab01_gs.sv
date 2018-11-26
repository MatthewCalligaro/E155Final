// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: SPI master to extract sampled voltages from ADC

module adc(input logic sclk, reset, start,
           input logic channel, 
           input logic miso,
           output logic mosi, ncs,
           output logic [9:0] voltage);

    logic [3:0] counter;
    logic lastStart;

    // Send data on the negative edge of the clock
    always_ff @(negedge sclk, posedge reset) begin 
        if (reset)  counter <= 0;
        else begin
            // Reset counter on start, otherwise count up to 15 and stop
            counter = (start && !lastStart) ? 4'b0 : (counter == 4'hF) ? 4'hF : counter + 4'b1;
            ncs = counter == 4'hF;                      // Hold ncs low for first 15 cycles
            mosi = channel ? 1'b1 : counter != 4'h2;    // ODD/SIGN = channel, all others are 1
            lastStart = start;
        end
    end

    // Read data on the positive edge of the clock 
    always_ff @(posedge sclk)
        if (counter >= 4'h5 && counter < 4'hF) voltage <= {voltage[8:0], miso};
endmodule

// Giselle Serate
// gserate@g.hmc.edu
// 2018.11.24
// Return intensity level according to HC-SR04 distance sensor. 
module distance(input logic clk,                // 40 MHz clock.
                input logic reset,              // Hardware reset. 
                input logic echo,               // Echo pin.
                output logic trig,              // Trigger pin.
                output logic[3:0] intensity);   // Intensity level--higher meaning closer.
    logic [5:0] ucount; // Counts up to 1 us; reset when you hit 40. 
    logic uclk; // Has a posedge once every us. 
    logic [15:0] counter; // Counts up once every us; proxy for state. 
    logic [11:0] accumulateresult;  // Keeps track of how long echo has been raised. 
    logic [11:0] saveresult;        // save persists the last value while accumulate gets the next value. 
                                    // If we assume a use range of 2 feet, we get 3552 us as our max. 
    
    // Generate us clock.
    always_ff@(posedge clk, posedge reset)
    begin
        if(reset) // Reset. 
            ucount = 0;
        else if (ucount == 6'd39) // Also reset. 
				ucount = 0;
		  else
		  begin
            ucount++;
				if(ucount % 20 == 0) // Hit half a us. 
					uclk = !uclk; 
		  end
    end
        
    always_ff@(posedge uclk, posedge reset)
    begin
        // Reset on 60 ms (60000 us).
        if(reset)
        begin
            saveresult = accumulateresult;
            counter = 0;
            accumulateresult = 0;
            trig = 1; // Raise trig, beginning of cycle. 
        end
		  else if(counter == 16'd59999)
		  begin
			   saveresult = accumulateresult;
            counter = 0;
            accumulateresult = 0;
            trig = 1; // Raise trig, beginning of cycle. 
		  end
        else
        begin
            if(counter == 16'd19) trig = 0; // Stop triggering; 10 us didn't work, so I bumped this to 20. 
            counter++; // Regardless of trigger state, continue counting.             
			   if(echo) // Count how long echo is raised. 
					 accumulateresult++;
        end

    end
        
    always_comb // Evenly split 3552us into intervals of 444. 
    begin
        if(saveresult > 12'd3552)           intensity = 3'd0; // Farthest; least intense. 
        else if(saveresult > 12'd3108)      intensity = 3'd1; 
        else if(saveresult > 12'd2664)      intensity = 3'd2;
        else if(saveresult > 12'd2220)      intensity = 3'd3;
        else if(saveresult > 12'd1776)      intensity = 3'd4;
        else if(saveresult > 12'd1332)      intensity = 3'd5;
        else if(saveresult > 12'd888)       intensity = 3'd6;
        else if(saveresult > 12'd444)       intensity = 3'd7;
        else if(saveresult > 0)             intensity = 3'd8; // Closest; most intense.
        else                                intensity = 3'd0; // If we see a value that we don't know how to handle, read a 0. 
    end
        
endmodule

// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: RAM module with read and write capabilities
// Code adapted from Digital Design and Computer Architecture, 455

module mem(input logic clk,
           input logic WE,
           input logic [12:0] A,
           input logic [10:0] WD,
           output logic [10:0] RD);
	
    // Maximum RAM size = 2^13
	logic [10:0] RAM[8191:0];    
	assign RD = RAM[A]; 
	
	always_ff@(posedge clk)
		if (WE) RAM[A] <= WD;

endmodule		

// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/13/2018
// Summary: SPI master to send voltages to the Raspberry Pi

module pi(input logic sclk, reset, start,
          input logic [10:0] voltage,
          output logic mosi, ncs);

    logic lastStart;
    logic [3:0] counter;
    logic [10:0] sendVoltage;    // Shift register for sending voltage

    // Send data on the negative edge of the clock
    always_ff @(negedge sclk, posedge reset) begin
        if (reset)  counter <= 0;
        else begin
            // Reset counter on start, otherwise count up to 15 and stop
            counter = (start && !lastStart) ? 1'b0 : (counter == 4'hF) ? 4'hF : counter + 1'b1;

            // Load sendVoltage on new cycle and shift out one bit at a time
            if (counter == 0)   sendVoltage = voltage;
            else                sendVoltage = {sendVoltage[9:0], 1'b0};

            ncs = counter >= 11;    // Hold ncs low for first 11 clock cycles
            lastStart = start;
        end
    end

    assign mosi = sendVoltage[10];
endmodule

// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: Top-level module for FPGA multi-effects 

module Lab01(input logic clk, reset, // TODO: I'm sorry
            input logic dinAdc,
            input logic [3:0] switch,
            input logic trig,
            output logic echo,
            output logic sclkAdc, doutAdc, ncsAdc, 
            output logic sclkPi, doutPi, ncsPi,
            output logic [7:0] led);
    
    // Clock and SPI
    logic [7:0] sclkGen;    // counter to generate sclks
    logic [9:0] counter;    // counter to sample at 48 KHz
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

    // Intensity of effects
    logic [3:0] intensity;

    // Modules
    adc adc1(sclkAdc, reset, spiStart, 1'b0, dinAdc, doutAdc, ncsAdc, sampleVoltage);
    pi pi1(sclkPi, reset, spiStart, {sendVoltageSign, sendVoltageMag}, doutPi, ncsPi);
    mem mem1(clk, WE, address, writeVoltage, readVoltage);
    distance distance1(clk, reset, trig, echo, intensity);

    // Registers
    always_ff @(posedge clk, posedge reset) begin
        // on reset, reset relevant registers and enter calibration mode
        if (reset) begin
            sclkGen <= 0;
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
                    if (switch[1])  sumVoltage <= (readVoltage[10] ? (sumVoltage - readVoltage[9:0]) : (sumVoltage + readVoltage[9:0]);
                    address <= writeAdr - 13'h200;
//                    address <= writeAdr - 13'h100- ((13'h100 * intensity) >> 3);						  
                end 
                10'h4: begin        // add chorus 1
                    if (switch[2])  sumVoltage <= (readVoltage[10] ? (sumVoltage - readVoltage[9:1]) : (sumVoltage + readVoltage[9:1]));
//                    address <= writeAdr - 13'h300;
						  address <= writeAdr - 13'h200 - ((13'h100 * intensity) >> 3);
                end
                10'h5: begin        // add chorus 2
                    if (switch[2])  sumVoltage <= (readVoltage[10] ? (sumVoltage - readVoltage[9:1]) : (sumVoltage + readVoltage[9:1]));
//                    address <= writeAdr - 13'h400;
						  address <= writeAdr - 13'h300 - ((13'h100 * intensity) >> 3);

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
                    // if (switch[0])  sendVoltageMag <= (sumVoltage > 16'h3FF-intensity*7'h70) ? 10'hFF : {sumVoltage[8:0], 1'b0}; // Bumped threshold down for higher intensity. 
                    else            sendVoltageMag <= (sumVoltage > 16'h3FF) ? 10'h3FF : sumVoltage[9:0];
                end
                10'h9: begin        // add solo effect by inverting sendVoltageMag
                    if (switch[3])  sendVoltageMag <= (sendVoltageMag > 4'hC) ? (-sendVoltageMag) >> 1 : 1'b0;
//						 if (switch[3])  sendVoltageMag <= (sendVoltageMag > 4'hC) ? (-sendVoltageMag) >> intensity : 1'b0;
                end 
                10'h10: begin        // update LEDs
                    led <= sendVoltageMag[9:2];
                end
            endcase

            // update counters
            sclkGen <= (counter == 10'd832) ? 1'b0 : sclkGen + 1'b1; 
            counter <= (counter == 10'd832) ? 1'b0 : counter + 1'b1;
        end
    end

    assign spiStart = counter < 10'd416;    // raises when counter == 0
    assign WE = counter == 10'd832;         // store writeVoltage on last clk of each cycle
    assign sclkAdc = sclkGen[3];            // ADC's sclk = 2.5 MHz (16 clks)
    assign sclkPi = sclkGen[5];             // Pi's sclk  = 625 KHz (64 clks)
endmodule
