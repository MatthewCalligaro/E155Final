// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/30/2018
// Summary: Calculates the voltage bias of the input signal

module calibrate(input logic reset,                 // hardware reset
                 input logic newSample,             // positive edge indicates new sample is ready
                 input logic [4:0] switch,          // hardware DIP switches
                 input logic [9:0] sampleVoltage,   // voltage sampled from the ADC
                 output logic [9:0] offset);        // voltage bias of the amplifier

    // Registers
    logic [31:0] offsetSum;             // sum of all samples collected during calibration period
    logic [12:0] calibrationSamples;    // the number of calibration samples taken so far
    logic [4:0] secondOffset;           // secondary offset configured with switches on reset

    always_ff @(posedge newSample, posedge reset) begin
        // Clear registers on reset (so we begin taking samples again) and load secondOffset
        if (reset) begin
            offsetSum <= 1'b0;
            calibrationSamples <= 1'b0;
            secondOffset <= switch;
        end 
        
        // Collect 4096 calibration samples and sum in offsetSum
        else if (calibrationSamples < 13'h1000) begin
            offsetSum <= offsetSum + sampleVoltage;
            calibrationSamples <= calibrationSamples + 1'b1;
        end
    end

    // Offset is the average of the 4096 calibration samples minus secondOffset
    assign offset = offsetSum[21:12] - (secondOffset << 1'b0);
endmodule
