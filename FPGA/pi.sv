// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/13/2018
// Summary:

module pi(input logic sclk, reset, start,
          input logic [9:0] voltage,
          output logic mosi, ncs);

    logic lastStart;
    logic [3:0] counter;
    logic [9:0] sendVoltage;    // Shift register for sending voltage

    // Send data on the negative edge of the clock
    always_ff @(negedge sclk, posedge reset) begin
        if (reset)  counter <= 0;
        else begin
            // Reset counter on start, otherwise count up to 15 and stop
            counter = (start && !lastStart) ? 4'b0 : (counter == 4'hF) ? 4'hF : counter + 4'b1;

            // Load sendVoltage on new cycle and shift out one bit at a time
            if (counter == 0)   sendVoltage = voltage;
            else                sendVoltage = {sendVoltage[8:0], 1'b0};

            ncs = counter >= 10;    // Hold ncs low for first 10 clock cycles
            lastStart = start;
        end
    end
        

    assign mosi = sendVoltage[9];
endmodule