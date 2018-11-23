// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: 

module testbench();    

logic clk, reset, dinAdc, sclkAdc, doutAdc, ncsAdc, sclkPi, doutPi, ncsPi;
logic [7:0] led;

logic [7:0] counter = 0;

FPGA dut(clk, reset, dinAdc, sclkAdc, doutAdc, ncsAdc, sclkPi, doutPi, ncsPi, led);

// Pulse reset
initial begin
    reset=0; #20; reset=1; #20; reset=0;
end

// Generate clk
always begin     
    clk=1; #5; clk=0; #5;    
end  

always_ff @(posedge clk) begin
    counter = counter + 1'b1;
end

assign dinAdc = counter[5];

endmodule
