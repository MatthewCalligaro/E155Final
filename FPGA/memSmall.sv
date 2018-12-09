// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: RAM module with read and write capabilities
// Code adapted from Digital Design and Computer Architecture, 455

module memSmall(input logic clk,            // 40 MHz clock
                input logic WE,             // write enable
                input logic [2:0] A,        // address
                input logic [11:0] WD,      // data to write to A when WE is asserted
                output logic [11:0] RD);    // data read from A
	
	logic [11:0] RAM[7:0];    
	assign RD = RAM[A]; 
	
	always_ff@(posedge clk)
		if (WE) RAM[A] <= WD;
endmodule	
	