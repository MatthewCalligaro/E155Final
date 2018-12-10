// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: Testbench to verify FPGA module

module testbench();
    // Declare inputs and outputs of dut
    logic clk, reset, dinAdc, sclkAdc, doutAdc, ncsAdc, sclkPi, doutPi, ncsPi;
    logic [7:0] led;
    logic [3:0] switch = 0;
    logic [7:0] counter = 0;

    // Top level FPGA module
    FPGA dut(clk, reset, dinAdc, switch, sclkAdc, doutAdc, ncsAdc, sclkPi, doutPi, ncsPi, led);

    // Pulse reset to initialize
    initial begin
        reset=0; #20; reset=1; #20; reset=0;
    end

    // Generate clk
    always begin     
        clk=1; #5; clk=0; #5;    
    end  

    // Increment counter
    always_ff @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // toggle simulated data from ADC
    assign dinAdc = counter[7];
endmodule
