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
	 logic [11:0] clean[10:0]; 			// Save the last 10 values.
	 logic [11:0] save; 					// Hold actual result.
                                    // Assuming a use range of 2 feet, the maximum is 3552 us.
    
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
	 
	always_ff@(posedge trig)
	begin
		clean[9] <= hold;
		clean[8] <= clean[9];
		clean[7] <= clean[8];
		clean[6] <= clean[7];
		clean[5] <= clean[6];
		clean[4] <= clean[5];
		clean[3] <= clean[4];
		clean[2] <= clean[3];
		clean[1] <= clean[2];
		clean[0] <= clean[1];
		// When in doubt, set save to max. 
		if(hold > 12'd3108 || clean[9] > 12'd3108 || clean[8] > 12'd3108 || clean[7] > 12'd3108 || clean[6] > 12'd3108 || clean[5] > 12'd3108  || clean[4] > 12'd3108 || clean[3] > 12'd3108 || clean[2] > 12'd3108 || clean[1] > 12'd3108 || clean[0] > 12'd3108)
			save <= 12'd3552; 
		else
			save <= hold;
	end
        
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
