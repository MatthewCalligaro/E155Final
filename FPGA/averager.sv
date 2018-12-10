// Name: Matthew Calligaro, Giselle Serate
// Email: mcalligaro@g.hmc.edu, gserate@g.hmc.edu
// Date: 12/9/2018
// Summary: Average the last 8 readings from the distance sensor

module averager(input logic clk,                // 40 MHz clock
                input logic reset,              // hardware reset        
                input logic trig,               // trigger pin of distance sensor
                input logic [11:0] newest,      // most recent distance detected
                input logic [11:0] oldest,      // oldest distance stored in ring buffer
                output logic [11:0] average);   // average of past 8 distances 

    // Registers
    logic [15:0] sum;       // sum of previous 8 distances
    logic [31:0] counter;   // counter to identify first 8 cycles
    logic lastTrig;         // value of trig last cycle

    always_ff@(posedge clk, posedge reset)
        // Clear registers on reset
        if(reset) begin
            sum <= 1'b0;
            counter <= 1'b0;
        end else begin
            lastTrig <= trig;
            
            // Update sum and counter on falling edge of trigger 
            else if (!trig & lastTrig) begin  
                // Do not subtract oldest on first 8 cycles
                sum <= sum + newest - (counter > 32'h8 ? oldest : 1'b0);
                counter <= counter + 1;
            end
        end 

    // Average is sum divided by 8
    assign average = sum[14:3];
endmodule 
