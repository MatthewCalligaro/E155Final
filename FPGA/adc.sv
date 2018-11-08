// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: 

module adc(input logic sclk, 
           input logic miso,
           output logic mosi, ncs,
           output logic [9:0] voltage);

    logic [4:0] counter = 0;

    // Send data on the negative edge of the clock
    always_ff @(negedge sclk)
    begin 
        counter = counter + 4'b1;   // Update counter first
        ncs = counter > 14;         // Hold ncs low for first 14 cycles
        mosi = counter != 2;        // ODD/SIGN is 0, all others are 1
    end

    // Read data on the positive edge of the clock 
    always_ff @(posedge sclk)
        if (counter >= 5 && counter < 15)
            voltage <= {voltage[8:0], miso};
endmodule
