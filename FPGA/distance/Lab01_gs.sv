// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: RAM module with read and write capabilities
// Code adapted from Digital Design and Computer Architecture, 455

// Ring buffer which always writes and reads on clock. 
module ring(input logic clk, reset,
            input logic [11:0] WD,
            output logic [11:0] RD);
			  
	logic [2:0] WA;
	logic [2:0] RA;
	logic [11:0] memory[14:0];
	
	always_ff@(posedge clk, posedge reset)
	begin
		if(reset) // Set read pointer one ahead of write pointer. 
		begin 
			WA <= 4'd7;
			RA <= 0;
		end
		else
		begin // Read and write data; update addresses. 
			memory[WA] <= WD;
			RD <= memory[RA];
			WA <= WA + 1;
			RA <= RA + 1;
		end
	end

endmodule

// Average current and last 6 data points. 
module saveavg(input logic clk, reset,
					input logic[11:0] latest,
					output logic[11:0] avg);
					
	logic [11:0] oldest;
	logic [15:0] sum;
	
	// Get oldest reading from memory, write newest reading.
	ring summem(clk, reset, latest, oldest);
	
	always_ff@(posedge clk, posedge reset)
	begin
		if(reset)
		begin
			sum = 15'd24864; // Initialize to a sum indicating low application of effects.
			avg = 12'd3552;
		end
		else
		begin
			// Update sum and calculate average. 
			sum <= sum - oldest;
			sum <= sum + latest;
			avg <= sum / 4'd7;
		end
	end
endmodule

// Giselle Serate
// gserate@g.hmc.edu
// 2018.11.24
// Turns on elements of an LED array according to HC-SR04 distance sensor. 
module Lab01(input logic clk,           // 40 MHz clock.
                input logic echo,          // Echo pin.
                output logic trig,         // Trigger pin.
                output logic[7:0] led);    // LED bars.
    // Track clock and state.
    logic [5:0] ucount;     // Counts up to 1 us; reset when you hit 40. 
    logic uclk;             // Has a posedge once every us. 
    logic [15:0] counter;   // Counts up once per us; proxy for state. 
    
    // Track how long echo has been raised. 
    logic [11:0] accumulateresult;  // Gets the next sensor value.
    logic [11:0] hold;              // Persists the last sensor value.
	 logic [11:0] clean[14:0]; 			// Save the last 10 values.
	 logic [11:0] save; 					// Hold actual result.
                                    // Assuming a use range of 2 feet, the maximum is 3552 us.
	
	integer i; // For loop var. It's a shift reg, so is legit?
    
    // Generate us clock.
    always_ff@(posedge clk)
    begin
        if(ucount == 6'd39) // Reset. 
            ucount = 0;
        else
            ucount++;
            
        if(ucount % 20 == 0) // Half a us has passed; flip clock. 
            uclk = !uclk; 
    end
        
    // Communicate with sensor. 
    always_ff@(posedge uclk)
    begin
        // Reset on 60 ms (60000 us).
        if(counter == 16'd59999)
        begin
           hold = accumulateresult;
            counter = 0;
            accumulateresult = 0;
            trig = 1; // Raise trig, beginning of cycle. 
        end
        else
        begin
            if(counter == 16'd19) trig = 0; // Stop triggering; the stated minimum of
                                            // 10 us didn't work, but 20 did.
            counter++; // Regardless of trigger state, continue counting. 
        end
            
        if(echo) // Count how long echo is raised. 
            accumulateresult++;
    end
	 
	 // Apply moving average filter. 
	saveavg smoother(trig, reset, hold, save);
        
    // Set LEDs according to latest distance reading. 
    always_comb // Split into intervals of 444. 
    begin
        led[7] = (save > 12'd3108);     // Indicates furthest distance. 
        led[6] = (save > 12'd2664);
        led[5] = (save > 12'd2220);
        led[4] = (save > 12'd1776);
        led[3] = (save > 12'd1332);
        led[2] = (save > 12'd888);
        led[1] = (save > 12'd444);
        led[0] = (save > 0);            // Indicates closest distance. 
    end
        
endmodule

