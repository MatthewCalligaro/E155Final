// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: RAM module for effects ring buffer
// Code adapted from Digital Design and Computer Architecture, 455

module mem(input logic clk,             // 40 MHz clock
           input logic WE,              // write enable
           input logic [12:0] A,        // address
           input logic [10:0] WD,       // data to write to A when WE is asserted
           output logic [10:0] RD);     // data read from A

	logic [10:0] RAM[8191:0];
	assign RD = RAM[A]; 

    // Write data if WE is asserted
	always_ff@(posedge clk)
		if (WE) RAM[A] <= WD;
endmodule
