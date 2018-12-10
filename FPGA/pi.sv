// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/13/2018
// Summary: SPI master to send voltages to the Raspberry Pi

module pi(input logic sclk,             // Pi slave clock (625 KHz) 
          input logic reset,            // hardware reset
          input logic start,            // positive edge indicates the start of a new round
          input logic [10:0] voltage,   // voltage to send to the Pi (sign-magnitude)
          output logic mosi,            // MOSI (data sent to Pi)
          output logic ncs);            // chip select for Pi

    // Registers
    logic [3:0] counter;        // counter to keep track of bits in the SPI exchange
    logic [10:0] sendVoltage;   // shift register storing next bit to send
    logic lastStart;            // value of start last cycle

    // Send data on the negative edge of the clock
    always_ff @(negedge sclk, posedge reset) begin
        // Clear registers on reset
        if (reset)  counter <= 0;
        else begin
            // Reset counter on start, otherwise count up to 15 and stop
            counter = (start && !lastStart) ? 1'b0 : (counter == 4'hF) ? 4'hF : counter + 1'b1;

            // Load sendVoltage on new cycle and shift out one bit at a time
            if (counter == 0)   sendVoltage = voltage;
            else                sendVoltage = {sendVoltage[9:0], 1'b0};

            // Hold ncs low for first 11 clock cycles
            ncs = counter >= 11;    
            lastStart = start;
        end
    end
    
    // Send top bit from shift register
    assign mosi = sendVoltage[10];
endmodule
