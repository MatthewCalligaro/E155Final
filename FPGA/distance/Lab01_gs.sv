// Giselle Serate
// 2018.11.24
// Top level module to turn on LED array according to HC-SR04 distance sensor. 
module Lab01(input logic clk, 			// 40 MHz clock.
				 input logic echo,			// Echo pin.
				 output logic trig,			// Trigger pin.
				 output logic[7:0] led);	// LED bars.
	logic [5:0] ucount; // Counts up to 1 us; reset when you hit 40. 
	logic uclk; // Has a posedge once every us. 
	logic [15:0] counter; // Counts up; proxy for state. 
	logic [11:0] accumulateresult; 	// Keeps track of how long echo has been raised. 
	logic [11:0] save; 					// If we assume a 10-foot max range (as in dsheet), we get 17760 us as our max. 
												// If instead we assume a use range of 2 feet, we get 3552 us. 
	
	// Generate us clock
	always_ff@(posedge clk)
	begin
		if(ucount == 6'd39) // Reset. 
			ucount = 0;
		else
			ucount++;
			
		if(ucount % 20 == 0) // Hit half a us. 
			uclk = !uclk; 
	end
		
	always_ff@(posedge uclk)
	begin
		// Reset on 60 ms (60000 us)
		if(counter == 16'd59999)
		begin
			save = accumulateresult;
			counter = 0;
			accumulateresult = 0;
			trig = 1; // Raise trig, beginning of cycle. 
		end
		else
		begin
			if(counter == 16'd19) trig = 0; // Stop triggering; 10 us didn't work, so I bumped this to 20. 
			counter++; // Regardless of trigger state, continue counting. 
		end
			
		if(echo) // Count how long echo is raised. 
			accumulateresult++;
	end
		
	always_comb // Evenly split into intervals of 444. 
	begin
		led[7] = (save > 12'd3108);
		led[6] = (save > 12'd2664);
		led[5] = (save > 12'd2220);
		led[4] = (save > 12'd1776);
		led[3] = (save > 12'd1332);
		led[2] = (save > 12'd888);
		led[1] = (save > 12'd444);
		led[0] = (save > 0);
	end
		
endmodule
