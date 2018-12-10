// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/30/2018
// Summary: Calculates the voltage bias of the input signal

module calibrate(input logic reset,                 // hardware reset
                 input logic newSample,             // positive edge indicates new sample is ready
                 input logic [9:0] sampleVoltage,   // voltage sampled from the ADC
                 output logic [9:0] offset);        // voltage bias of the amplifier

    // Registers
    logic [31:0] offsetSum;             // sum of all samples collected during calibration period
    logic [12:0] calibrationSamples;    // the number of calibration samples taken so far

    always_ff @(posedge newSample, posedge reset) begin
        // Clear registers on reset (so we begin taking samples again)
        if (reset) begin
            offsetSum <= 0;
            calibrationSamples <= 0;
        end 
        
        // Collect 4096 calibration samples and sum in offsetSum
        else if (calibrationSamples < 13'h1000) begin
            offsetSum <= offsetSum + sampleVoltage;
            calibrationSamples <= calibrationSamples + 1'b1;
        end
    end

    // Offset is the average of the 4096 calibration samples
    assign offset = offsetSum[21:12];
endmodule
