// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: 
// Code adapted from Digital Design and Computer Architecture, 455

module mem(input logic clk,
           input logic WE,
           input logic [12:0] A,
           input logic [9:0] WD,
           output logic [9:0] RD);
	
	logic [9:0] RAM[8191:0];    // Maximum allowable RAM = 2^13
	assign RD = RAM[A]; 
	
	always_ff@(posedge clk)
		if (WE) RAM[A] <= WD;

endmodule		
