// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: 

module FPGA(input logic clk, 
            input logic miso0, 
            output logic sclk, mosi0, ncs0, 
            output logic [7:0] led);
    
    logic [9:0] tempVoltage, voltage;

    // Slow down the clock to roughly 1 MHz
    logic[4:0] counter = 0;
    always_ff @(posedge clk)
        counter += 5'b1;

    adc adc1(sclk, miso0, mosi0, ncs0, tempVoltage);
    // When we are not currently sampling, update voltage
    always_ff @(posedge sclk)
        if (ncs0) voltage <= tempVoltage;

    assign sclk = counter[4];
    assign led = voltage[9:2];
endmodule
