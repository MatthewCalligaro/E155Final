// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: SPI master to extract sampled voltages from ADC

module adc(input logic sclk,            // ADC slave clock (2.5 MHz)
           input logic reset,           // hardware reset
           input logic start,           // positive edge indicate the start of a new round
           input logic channel,         // channel to read from ADC
           input logic miso,            // MISO (data read from ADC)
           output logic mosi,           // MOSI (data sent to ADC)
           output logic ncs,            // chip select for ADC
           output logic [9:0] voltage); // shift register storing voltage read from ADC

    // Registers
    logic [3:0] counter;    // counter to keep track of bits in the SPI exchange
    logic lastStart;        // value of start last cycle 

    // Send data on the negative edge of the clock
    always_ff @(negedge sclk, posedge reset) 
        // Clear registers on reset
        if (reset)  counter <= 0;
        else begin
            // Reset counter on raising edge of start, otherwise count up to 15 and stop
            counter = (start && !lastStart) ? 4'b0 : (counter == 4'hF) ? 4'hF : counter + 4'b1;

            // Hold ncs low for first 15 cycles
            ncs = counter == 4'hF;

            // ODD/SIGN = channel, all calibration bits are 1    
            mosi = channel ? 1'b1 : counter != 4'h2;
            lastStart = start;
        end

    // Read data on the positive edge of the clock 
    always_ff @(posedge sclk)
        if (counter >= 4'h5 && counter < 4'hF) voltage <= {voltage[8:0], miso};
endmodule
