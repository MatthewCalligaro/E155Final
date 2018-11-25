// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: RAM module with read and write capabilities
// Code adapted from Digital Design and Computer Architecture, 455

module mem(input logic clk,
           input logic WE,
           input logic [12:0] A,
           input logic [10:0] WD,
           output logic [10:0] RD);
	
    // Maximum RAM size = 2^13
	logic [10:0] RAM[8191:0];    
	assign RD = RAM[A]; 
	
	always_ff@(posedge clk)
		if (WE) RAM[A] <= WD;

endmodule		
