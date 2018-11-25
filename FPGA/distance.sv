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
    logic [15:0] counter; // Counts up; proxy for state. 
    logic [11:0] accumulateresult;  // Keeps track of how long echo has been raised. 
                                    // If we assume a 10-foot max range (as in dsheet), we get 17760 us as our max. 
                                    // If instead we assume a use range of 2 feet, we get 3552 us. 
    
    // Generate us clock.
    always_ff@(posedge clk, posedge reset)
    begin
        if(reset || ucount == 6'd39) // Reset. 
            ucount = 0;
        else
            ucount++;
            
        if(ucount % 20 == 0) // Hit half a us. 
            uclk = !uclk; 
    end
        
    always_ff@(posedge uclk, posedge reset)
    begin
        // Reset on 60 ms (60000 us).
        if(reset || counter == 16'd59999)
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
        if(save > 12'd3108)         intensity = 4'd0; // Farthest; least intense. 
        else if(save > 12'd2664)    intensity = 4'd1;
        else if(save > 12'd2220)    intensity = 4'd2;
        else if(save > 12'd1776)    intensity = 4'd3;
        else if(save > 12'd1332)    intensity = 4'd4;
        else if(save > 12'd888)     intensity = 4'd5;
        else if(save > 12'd444)     intensity = 4'd6;
        else if(save > 0)           intensity = 4'd7; // Closest; most intense.
        else                        intensity = 4'd0; // If we see a value that we don't know how to handle, read a 0. 
    end
        
endmodule
