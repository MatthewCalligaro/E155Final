// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: 

module testbench();    

logic clk, sclk, mosi, ncs;
logic [7:0] led;

logic miso;
logic [4:0] counter = 0;

FPGA dut(clk, miso, sclk, mosi, ncs, led);

always begin     
    clk=1; #5; clk=0; #5;    
end  

always_ff @(posedge sclk) begin
    counter = counter + 1'b1;
    miso = !(counter == 7 || counter == 9 || counter == 12); 
end

endmodule
