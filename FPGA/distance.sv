// Name: Giselle Serate
// Email: gserate@g.hmc.edu
// Date: 11/30/2018
// Summary: Top-level module for interfacing with distance sensor

module distance(input logic clk,                // 40 MHz clock
                input logic reset,              // hardware reset
                input logic echo,               // echo pin of distance sensor
                output logic trig,              // trigger pin of distance sensor
                output logic [3:0] intensity);  // intensity level with higher meaning closer
    
    // Declare wires between modules
    logic [11:0] newest, oldest, average; 
    logic [2:0] address;
    logic WE;

    // Declare modules
    averager averager1(trig, reset, newest, oldest, average);
    memSmall memSmall2(clk, !trig, address, newest, oldest);
    distsensor distsensor1(clk, reset, echo, trig, newest, address, WE);
    intensity getintensity(average, intensity);
    
endmodule
