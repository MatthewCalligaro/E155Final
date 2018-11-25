// Giselle Serate
// gserate@g.hmc.edu
// 2018.09.09
// Top level module to blink LEDs and set 7seg display 
// according to passed clock and switches. 
module Lab01(input logic clk, 			// 40 MHz clock
				 input logic echo,			// Echo pin
				 output logic trig,			// Trigger pin
				 output logic[7:0] led);	// LED bars
	logic [5:0] ucount; // Counts up to 1 us; reset when you hit 40. 
	logic uclk; // Posedge once every us. 
	logic [15:0] counter; // Counts up; proxy for state. 
	logic [11:0] accumulateresult; 	// Keeps track of how long echo has been raised. 
	logic [11:0] save; 					// If we assume a 10-foot max range (as in dsheet), we get 17760 us as our max. 
												// If instead we assume a use range of 2 feet, we get 3552. 
	
	// Generate us clock
	always_ff@(posedge clk)
	begin
		if(ucount == 6'd40)
			ucount = 0;
		else
			ucount++;
			
		if(ucount % 20 == 0)
			uclk = !uclk;
	end
		
	always_ff@(posedge uclk)
	begin
		// Reset on 60 ms or 60000 us
		if(counter == 16'd60000)
		begin
			led[0] = 1;
			save = accumulateresult;
			counter = 0;
			accumulateresult = 0;
			trig = 1; // Raise trig, beginning of cycle. 
		end
		else
		begin
			if(counter == 16'd20) trig = 0; 
			counter++; // Always do this, regardless of triggering. 
		end
			
		if(echo)
			accumulateresult++;
	end
	
//	assign led[0] = (uclk == 0);
		
	always_comb
	begin
		led[7] = (save > 12'd3108);
		led[6] = (save > 12'd2664);
		led[5] = (save > 12'd2220);
		led[4] = (save > 12'd1776);
		led[3] = (save > 12'd1332);
		led[2] = (save > 12'd888);
		led[1] = (save > 12'd444);
//		led[0] = (save > 0);
	end

//		assign led[7] = (save > 12'd3108);
//		assign led[6] = (save > 12'd2664);
//		assign led[5] = (save > 12'd2220);
//		assign led[4] = (save > 12'd1776);
//		assign led[3] = (save > 12'd1332);
//		assign led[2] = (save > 12'd888);
//		assign led[1] = (save > 12'd444);
//		assign led[0] = (save > 0);
		
endmodule
