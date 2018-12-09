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


// Calculate average of current and last 7 data points. 
// Keeps running sum, adding latest and subtracting oldest to obtain updated sum. 
module averager(input logic clk, reset,
                input logic trig, 
                input logic[11:0] latest, oldest,
                output logic[11:0] avg);

    logic trigHigh; // If we expect trig to currently be high or not. 
    logic [15:0] sum; // Saved sum across runs; used to calculate average. 
    logic [2:0] gettingvalues; // Are we still getting readings for the initial sum?
    logic [15:0] result; // Intermediate to extract lowest bits for average. 

    always_ff@(posedge clk, posedge reset)
    begin
        if(reset)
        begin
            sum = 15'h3800; // Initialize at far distance (no effects). 
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
                    sum -= 12'h100;
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
    
    // Calculate average of eight points. 
    assign result = (sum + oldest) >> 2'h3; 
    assign avg = result[11:0]; // Truncate result. 
endmodule 


// Average current and last 7 data points. 
module saveavg(input logic clk, reset,
               input logic trig,
               input logic[11:0] latest,
               output logic[11:0] avg);
                    
    logic [11:0] oldest; // Oldest reading saved in memory. 
    
    // Get oldest reading from memory, write newest reading.
    ring summem(clk, reset, trig, latest, oldest);
    averager calcavg(clk, reset, trig, latest, oldest, avg);
endmodule


// Communicate with distance sensor and output a measurement.
module distsensor(input logic clk, reset, 
                  input logic echo,
                  output logic trig,
                  output logic[11:0] hold); // Persists the last sensor value.
    // Track clock and state.
    logic [5:0] clkcounter; 
    logic slowclk;
    logic [15:0] counter; // Counts up with slowclk; proxy for state. 
    logic [11:0] accumulateresult;  // Keeps track of how long echo has been raised. 
    
    // Generate slower clock.
    always_ff@(posedge clk, posedge reset) begin
        if(reset) // Reset. 
            clkcounter = 1'b0;
        else
            clkcounter++;
    end

    assign slowclk = clkcounter[4]; // 1.25 MHz
        
    // Communicate with sensor. 
    always_ff@(posedge slowclk, posedge reset) begin
        if(reset) begin
            hold = accumulateresult;
            counter = 1'b0;
            accumulateresult = 1'b0;
            trig = 1'b1; // Raise trig, beginning of cycle. 
        end else begin
            // Reset on 60 ms (60000 us).
            if(counter == 16'hbb80) begin
                hold = accumulateresult;
                counter = 1'b0;
                accumulateresult = 1'b0;
                trig = 1'b1; // Raise trig, beginning of cycle. 
            end else begin
                if(counter == 16'h10) trig = 1'b0; // Stop triggering. 
                counter++; // Regardless of trigger state, continue counting. 
                if(echo) // Count how long echo is raised. 
                    accumulateresult++;
            end
        end
    end
endmodule


// Translate saved measurement to an intensity. // TODO is this ridiculous?
module intensity(input logic[15:0] save,
                 output logic[3:0] intensity);
    always_comb
    begin
        if(save > 12'h800)           intensity = 4'h0; // Farthest; least intense. 
        else if(save > 12'h700)      intensity = 4'h1; 
        else if(save > 12'h600)      intensity = 4'h2;
        else if(save > 12'h500)      intensity = 4'h3;
        else if(save > 12'h400)      intensity = 4'h4;
        else if(save > 12'h300)      intensity = 4'h5;
        else if(save > 12'h200)      intensity = 4'h6;
        else if(save > 12'h100)      intensity = 4'h7;
        else if(save > 1'b0)         intensity = 4'h8; // Closest; most intense.
        else                         intensity = 4'h0; // If we see a value that we don't know how to handle, read a 0. 
    end
endmodule


// Return intensity level according to HC-SR04 distance sensor. 
module distance(input logic clk,                // 40 MHz clock.
                input logic reset,              // Hardware reset. 
                input logic echo,               // Echo pin.
                output logic trig,              // Trigger pin.
                output logic[3:0] intensity);   // Intensity level--higher meaning closer.
    
    logic [11:0] hold;              // hold persists the latest measurement. 
    logic [15:0] save;              // save persists the averaged value. 

    // Get distance. 
    distsensor getdistance(clk, reset, echo, trig, hold);

    // Apply moving average filter. 
    saveavg smoother(clk, reset, trig, hold, save);

    intensity getintensity(save, intensity);
    
endmodule
