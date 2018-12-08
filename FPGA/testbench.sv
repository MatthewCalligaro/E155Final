// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: Testbench to verify FPGA module

module testbench();    
    logic clk, reset, dinAdc, sclkAdc, doutAdc, ncsAdc, sclkPi, doutPi, ncsPi;
    logic [7:0] led;
    logic [3:0] switch = 0;
    logic [7:0] counter = 0;

    FPGA dut(clk, reset, dinAdc, switch, sclkAdc, doutAdc, ncsAdc, sclkPi, doutPi, ncsPi, led);

    // Pulse reset
    initial begin
        reset=0; #20; reset=1; #20; reset=0;
    end

    // Generate clk
    always begin     
        clk=1; #5; clk=0; #5;    
    end  

    always_ff @(posedge clk) begin
        counter <= counter + 1'b1;
    end
    assign dinAdc = counter[5];
endmodule

module testbench2();    
    logic [9:0] sampleVoltage = 1'b0;
    logic [9:0] offset = 10'h1FF;
    logic [10:0] preprocVoltage;
    logic clk;

    preprocess dut(sampleVoltage, offset, preprocVoltage);

    // Generate clk
    always begin     
        clk=1; #5; clk=0; #5;    
    end  

    always_ff @(posedge clk) begin
        sampleVoltage <= sampleVoltage + 1;
        if (sampleVoltage == 10'h3FF) $stop;
    end
endmodule