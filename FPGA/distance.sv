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