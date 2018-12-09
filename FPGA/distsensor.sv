// Name: Matthew Calligaro, Giselle Serate
// Email: mcalligaro@g.hmc.edu, gserate@g.hmc.edu
// Date: 12/9/2018
// Summary: Reads distance from the distance sensor

module distsensor(input logic clk,              // 40 MHz clock 
                  input logic reset,            // hardware reset
                  input logic echo,             // echo pin of distance sensor
                  output logic trig,            // trigger pin of distance sensor
                  output logic [11:0] newest,   // register storing most recent distance detected 
                  output logic [2:0] address,   // read or write address for ring buffer
                  output logic WE);             // write enable for ring buffer

    // Registers
    logic [23:0] counter;       // counter to control timing 
    logic [16:0] accumulator;   // keeps track of how long echo has been raised
    
    always_ff@(posedge clk, posedge reset)
        if(reset) begin
            counter <= 1'b0;
            address <= 1'b0;
        end else begin
            counter <= (counter == 24'h249F00) ? 1'b0 : counter + 1'b1;

            if (counter == 24'h0) begin
                trig <= 1'b1;
                accumulator <= 1'b0;
                newest <= accumulator[16:5];
            end 
            else if (counter == 24'h1)      address <= address + 1'b1;
            else if (counter == 24'h320)    trig <= 1'b0;
            else if (counter > 24'h320)     accumulator <= accumulator + echo;
        end

    // Write on the 1 index clk of each round
    assign WE = (counter == 1'b1);
endmodule
