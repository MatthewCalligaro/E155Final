// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/7/2018
// Summary: 

module adc(input logic sclk, reset, start,
           input logic channel, 
           input logic miso,
           output logic mosi, ncs,
           output logic [9:0] voltage);

    logic [3:0] counter;
    logic lastStart;

    // Send data on the negative edge of the clock
    always_ff @(negedge sclk, posedge reset) begin 
        if (reset)  counter <= 0;
        else begin
            // Reset counter on start, otherwise count up to 15 and stop
            counter = (start && !lastStart) ? 4'b0 : (counter == 4'hF) ? 4'hF : counter + 4'b1;
            
            ncs = counter == 4'hF;                      // Hold ncs low for first 15 cycles
            mosi = channel ? 1'b1 : counter != 4'h2;    // ODD/SIGN = channel, all others are 1
            lastStart = start;
        end
    end

    // Read data on the positive edge of the clock 
    always_ff @(posedge sclk)
        if (counter >= 4'h5 && counter < 4'hF)  voltage <= {voltage[8:0], miso};
endmodule
