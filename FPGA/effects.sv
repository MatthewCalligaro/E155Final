// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/30/2018
// Summary: Applies effects to audio signal

module effects(input logic reset, clk,
               input logic [4:0] switch,
               input logic [9:0] counter, sampleVoltage, offset,
               input logic [10:0] readVoltage,
               input logic [3:0] distance,
               output logic [10:0] sendVoltage, writeVoltage,
               output logic [12:0] address);

    // Registers
    logic [9:0] repCounter;     // counter used for repeater effect 
    logic [12:0] writeAdr;      // current address we are writing to
    logic increaseAdr;          // indicates whether we should increase writeAdr this cycle
    logic [15:0] sumVoltage;    // voltage calculated as effects are applied (2's comp)

    // Wires
    logic [15:0] sampleExt;     // sampleVoltage extended to 15 bits
    logic [15:0] offsetExt;     // offset extended to 15 bits 
    logic [15:0] sumVoltageAbs; // absolute value of sumVoltage (2's comp)
    logic [15:0] overdriven;    // signal with overdrive affect applied if on (2's comp)
    logic [9:0] saturated;      // saturated signal (unsigned)
    logic [9:0] sendVoltageMag; // magnitude of sendVoltage (unsigned)

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            writeAdr <= 0;
        end else begin
            case (counter)
                10'h0: begin        // load in preprocVoltage
                    writeAdr <= writeAdr + increaseAdr;
                    increaseAdr <= !increaseAdr;
                    address <= writeAdr + 1'b1 + (switch[4] ? distance << 9 : 1'b0);
                    repCounter <= repCounter + distance;
                    sumVoltage <= sampleExt - offsetExt + (switch[4] ? 1'b0 : 4'hF);
                end
                10'h1: begin        // add digital delay signal
                    if (switch[1])  sumVoltage <= (readVoltage[10] ? 
                        (sumVoltage - readVoltage[9:0]) : (sumVoltage + readVoltage[9:0]));
                    address <= writeAdr - (switch[4] ? distance << 8 : 13'h200);
                end 
                10'h2: begin        // add chorus 1 signal
                    if (switch[2])  sumVoltage <= (readVoltage[10] ? 
                        (sumVoltage - readVoltage[9:1]) : (sumVoltage + readVoltage[9:1]));
                    address <= writeAdr - (switch[4] ? distance << 8 + distance << 7 : 13'h300);
                end
                10'h3: begin        // add chorus 2 signal
                    if (switch[2])  sumVoltage <= (readVoltage[10] ? 
                        (sumVoltage - readVoltage[9:1]) : (sumVoltage + readVoltage[9:1]));
                    address <= writeAdr - (switch[4] ? distance << 9 : 13'h400);
                end
                10'h4: begin        // add chorus 3 signal
                    if (switch[2])  sumVoltage <= (readVoltage[10] ? 
                        (sumVoltage - readVoltage[9:1]) : (sumVoltage + readVoltage[9:1]));
                    address <= writeAdr;
                end 
            endcase
        end
    end

    // Magnitude of preproVoltage extended to 15 bits
    assign sampleExt = sampleVoltage;
    assign offsetExt = offset;

    // Absolute value of sumVoltage
    assign sumVoltageAbs = sumVoltage[15] ? -sumVoltage : sumVoltage; 

    // Apply overdrive if on by amplifying voltage above a certain threshold
    assign overdriven = (switch[0] && sumVoltageAbs > 8'h1F) ? 
        (switch[4] ? (sumVoltageAbs << distance[3:1]) : (sumVoltageAbs << 2)) : sumVoltageAbs;

    // Saturate signal (using a lower threshold if overdrive is on)
    assign saturated = switch[0] ?
        (overdriven > 16'hFF ? 10'hFF : overdriven[9:0]) :
        (overdriven > 16'h3FF ? 10'h3FF : overdriven[9:0]);

    // Apply solo effect if on by filtering voltages below a threshold and inverting
    assign sendVoltageMag = switch[3] ?
        ((saturated < 4'hC || (switch[4] && repCounter[9] && distance > 1'b0)) ? 
            1'b0 : ((-saturated) >> 1)) : 
        saturated;

    // Construct sendVoltage as a sign-magnitude representation
    assign sendVoltage = {sumVoltage[15], sendVoltageMag};

    // Remove offset but do not apply effects for the voltage stored in RAM
    assign writeVoltage = ((sampleVoltage + 4'h8) > offset) ? 
        {1'b0, sampleVoltage + 4'hF - offset} : {1'b1, offset - sampleVoltage + 4'hF};
endmodule
