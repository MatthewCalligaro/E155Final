// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/30/2018
// Summary: Calculates the voltage bias on the input signal

module calibrate(input logic reset, newSample,
                 input logic [9:0] sampleVoltage,
                 output logic [9:0] offset);

    logic [31:0] offsetSum;             // sum of all samples during calibration period
    logic [12:0] calibrationSamples;    // the number of calibration samples taken so far

    always_ff @(posedge newSample, posedge reset) begin
        // On reset, clear registers so we begin taking samples again
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
    // assign offset = 10'h200;
endmodule
