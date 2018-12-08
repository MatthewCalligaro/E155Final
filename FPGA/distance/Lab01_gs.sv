// Giselle Serate
// gserate@g.hmc.edu
// 2018.11.30
// Sets LED bars according to the distance read from HC-SR04 ultrasonic sensor. 
// Applies boxcar average filter. 

// Ring buffer which simultaneously writes and reads after trigger is set high. 
module ring(input logic clk, reset, trig,
            input logic [11:0] WD,
            output logic [11:0] RD);
              
    logic trigHigh; // If we expect trig to currently be high or not. 
    logic [2:0] WA;
    logic [2:0] RA;
    logic [11:0] memory[14:0];
    
    always_ff@(posedge clk, posedge reset)
    begin
        if(reset) 
        begin 
            // Initialize read pointer one ahead of write pointer. 
            WA <= 4'd7;
            RA <= 0;
            trigHigh <= 0;
        end
        else
        if(!trigHigh) // Waiting for trig to go high. 
        begin
            if(trig) // Trig went high. Handle. 
            begin
                trigHigh <= 1;
                // Read and write data; update addresses. 
                memory[WA] <= WD;
                RD <= memory[RA];
                WA <= WA + 1;
                RA <= RA + 1;
          end
        end
        else trigHigh = trig; // Trig is high; idle until trig is low again. 
    end

endmodule

// Average current and last 6 data points. 
module saveavg(input logic clk, reset,
               input logic trig,
               input logic[11:0] latest,
               output logic[11:0] avg);
                    
    logic trigHigh; // If we expect trig to currently be high or not. 
    logic [11:0] oldest; // Oldest reading saved in memory. 
    logic [15:0] sum; // Saved sum across runs; used to calculate average. 
    logic [2:0] gettingvalues; // Are we still getting readings for the initial sum?
    
    // Get oldest reading from memory, write newest reading.
    ring summem(clk, reset, trig, latest, oldest);
    
    always_ff@(posedge clk, posedge reset)
    begin
        if(reset)
        begin
            sum = 15'd24864; // Initialize at far distance (no effects). 
            gettingvalues = 0;
            trigHigh = 0;
        end
        else
        if(!trigHigh) // Waiting for trig to go high. 
        begin
            if(trig) // Trig went high. Handle. 
            begin
                trigHigh = 1;
                if(gettingvalues < 3'd6) gettingvalues++;
                else
                begin
                    // Update sum. 
                    sum -= oldest;
                    sum += latest;
                end
            end
        end
        else trigHigh = trig; // Trig is high; idle until trig is low again. 
    end
    
    // Calculate average of seven points. 
    assign avg = sum / 4'd7; 

endmodule

// Top level module that turns on elements of an LED array according to HC-SR04 distance sensor. 
module Lab01(input logic clk,           // 40 MHz clock.
             input logic reset,         // Hardware reset. 
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
    logic [11:0] save;              // Hold actual result.
                                    // Assuming a use range of 2 feet, the maximum is 3552 us.
    
    // Generate us clock.
    always_ff@(posedge clk, posedge reset)
    begin
        if(reset) // Reset.
            ucount = 0;
        else if(ucount == 6'd39) // Also reset. 
            ucount = 0;
        else
            ucount++;
            if(ucount % 20 == 0) // Half a us has passed; flip clock. 
                uclk = !uclk; 
    end
        
    // Communicate with sensor. 
    always_ff@(posedge uclk, posedge reset)
    begin
        if(reset) // Reset. 
        begin
            hold = accumulateresult;
            counter = 0;
            accumulateresult = 0;
            trig = 1; // Raise trig, beginning of cycle. 
        else if(counter == 16'd59999) // Also reset on 60 ms (60000 us).
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
    saveavg smoother(clk, reset, trig, hold, save);
        
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
