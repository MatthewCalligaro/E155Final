// Giselle Serate
// gserate@g.hmc.edu
// 2018.11.30
// Returns intensity from distance sensor. 

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
            WA <= 3'h7;
            RA <= 1'b0;
            trigHigh <= 1'b0;
        end
        else
        if(!trigHigh) // Waiting for trig to go high. 
        begin
            if(trig) // Trig went high. Handle. 
            begin
                trigHigh <= 1'b1;
                // Read and write data; update addresses. 
                memory[WA] <= WD;
                RD <= memory[RA];
                WA <= WA + 1'b1;
                RA <= RA + 1'b1;
            end
        end
        else trigHigh = trig; // Trig is high; idle until trig is low again. 
    end

endmodule


// Calculate average of current and last 6 data points. 
// Keeps running sum, adding latest and subtracting oldest to obtain updated sum. 
module averager(input logic clk, reset,
                input logic trig, 
                input logic[11:0] latest, oldest,
                output logic[15:0] avg);

    logic trigHigh; // If we expect trig to currently be high or not. 
    logic [15:0] sum; // Saved sum across runs; used to calculate average. 
    logic [2:0] gettingvalues; // Are we still getting readings for the initial sum?

    always_ff@(posedge clk, posedge reset)
    begin
        if(reset)
        begin
            sum = 15'h6120; // Initialize at far distance (no effects). 
            gettingvalues = 1'b0;
            trigHigh = 1'b0;
        end
        else
        if(!trigHigh) // Waiting for trig to go high. 
        begin
            if(trig) // Trig went high. Handle. 
            begin
                trigHigh = 1'b1;
                if(gettingvalues <= 3'h6) 
                begin
                    gettingvalues++;
                    sum -= 12'hde0;
                    sum += latest;
                end
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
    assign avg = sum / 3'h7; 
endmodule 


// Average current and last 6 data points. 
module saveavg(input logic clk, reset,
               input logic trig,
               input logic[11:0] latest,
               output logic[15:0] avg);
                    
    logic [11:0] oldest; // Oldest reading saved in memory. 
    
    // Get oldest reading from memory, write newest reading.
    ring summem(clk, reset, trig, latest, oldest);
    averager calcavg(clk, reset, trig, latest, oldest, avg);
endmodule


// Return intensity level according to HC-SR04 distance sensor. 
module distance(input logic clk,                // 40 MHz clock.
                input logic reset,              // Hardware reset. 
                input logic echo,               // Echo pin.
                output logic trig,              // Trigger pin.
                output logic[3:0] intensity);   // Intensity level--higher meaning closer.
    
    // Track clock and state.
    logic [5:0] ucount; // Counts up to 1 us; reset when you hit 40. 
    logic uclk; // Has a posedge once every us. 
    logic [15:0] counter; // Counts up once every us; proxy for state. 
    logic [11:0] accumulateresult;  // Keeps track of how long echo has been raised. 
    logic [11:0] hold;              // Persists the last sensor value.
    logic [15:0] save;              // save persists the last value while accumulate gets the next value. 
                                    // If we assume a use range of 2 feet, we get 3552 us as our max. 
    
    // Generate us clock.
    always_ff@(posedge clk, posedge reset)
    begin
        if(reset) // Reset. 
            ucount = 1'b0;
        else
        begin
            if(ucount == 6'h27) // Reset. 
                ucount = 1'b0;
            else
                ucount++;
                
            if(ucount % 20 == 1'b0) // Half a us has passed; flip clock. 
                uclk = !uclk; 
        end
    end
        
    // Communicate with sensor. 
    always_ff@(posedge uclk, posedge reset)
    begin
        if(reset)
        begin
            hold = accumulateresult;
            counter = 1'b0;
            accumulateresult = 1'b0;
            trig = 1'b1; // Raise trig, beginning of cycle. 
        end
        else
        begin
            // Reset on 60 ms (60000 us).
            if(counter == 16'hea5f)
            begin
                hold = accumulateresult;
                counter = 1'b0;
                accumulateresult = 1'b0;
                trig = 1'b1; // Raise trig, beginning of cycle. 
            end
            else
            begin
                if(counter == 16'h13) trig = 1'b0; // Stop triggering; the stated minimum of
                                                   // 10 us didn't work, but 20 did.
                counter++; // Regardless of trigger state, continue counting. 
                if(echo) // Count how long echo is raised. 
                    accumulateresult++;
            end
        end

    end
     
     // Apply moving average filter. 
    saveavg smoother(clk, reset, trig, hold, save);

    always_comb // Evenly split 3552us into intervals of 444. 
    begin
        if(save > 12'hde0)           intensity = 4'h0; // Farthest; least intense. 
        else if(save > 12'hc24)      intensity = 4'h1; 
        else if(save > 12'ha68)      intensity = 4'h2;
        else if(save > 12'h8ac)      intensity = 4'h3;
        else if(save > 12'h6f0)      intensity = 4'h4;
        else if(save > 12'h534)      intensity = 4'h5;
        else if(save > 12'h378)      intensity = 4'h6;
        else if(save > 12'h1bc)      intensity = 4'h7;
        else if(save > 1'b0)         intensity = 4'h8; // Closest; most intense.
        else                         intensity = 4'h0; // If we see a value that we don't know how to handle, read a 0. 
    end
    
endmodule
