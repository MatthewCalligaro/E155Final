// Name: Matthew Calligaro
// Email: mcalligaro@g.hmc.edu
// Date: 11/30/2018
// Summary: Applies effects to audio signal

module effects(input logic clk,                     // 40 MHz clock
               input logic reset,                   // hardware reset
               input logic [4:0] switch,            // hardware switches choosing effects
               input logic [9:0] counter,           // counter used to synchronize rounds
               input logic [9:0] sampleVoltage,     // voltage sampled from the ADC
               input logic [9:0] offset,            // voltage bias detected in calibration
               input logic [10:0] readVoltage,      // voltage read from ring buffer
               input logic [3:0] intensity,         // intensity detected by distance sensor
               output logic [10:0] sendVoltage,     // voltage to send to Pi
               output logic [10:0] writeVoltage,    // voltage to write to ring buffer
               output logic [12:0] address);        // register storing address of ring buffer

    // Registers
    logic [15:0] repCounter;    // counter used for repeater effect 
    logic [12:0] writeAdr;      // current address we are writing to
    logic increaseAdr;          // indicates whether we should increase writeAdr this cycle
    logic [15:0] sumVoltage;    // voltage calculated as effects are applied (2's comp)

    // Wires
    logic [15:0] sampleExt;     // sampleVoltage extended to 15 bits
    logic [15:0] offsetExt;     // offset extended to 15 bits 
    logic [15:0] offsetVoltage; // voltage after removing offset (2's comp)
    logic [15:0] sumVoltageAbs; // absolute value of sumVoltage (unsigned)
    logic [15:0] overdriven;    // signal with overdrive affect applied if on (unsigned)
    logic [15:0] threshold;     // value at which to saturate (unsigned)
    logic [9:0] saturated;      // saturated signal (unsigned)
    logic [9:0] sendVoltageMag; // magnitude of sendVoltage (unsigned)

    always_ff @(posedge clk, posedge reset) begin
        // Clear registers on reset
        if (reset) begin
            writeAdr <= 0;
            repCounter <= 0;
            increaseAdr <= 0;
        end else begin
            // Apply effects that require loading data from ring buffer and add into sumVoltage
            case (counter)
                10'h0: begin        // load in preprocVoltage
                    writeAdr <= writeAdr + increaseAdr;
                    increaseAdr <= !increaseAdr;
                    address <= writeAdr + 1'b1 + (switch[4] ? intensity << 9 : 1'b0);
                    repCounter <= repCounter + intensity;
                    sumVoltage <= offsetVoltage;
                end
                10'h1: begin        // add digital delay signal (if on)
                    if (switch[1])  sumVoltage <= (readVoltage[10] ? 
                        (sumVoltage - readVoltage[9:0]) : (sumVoltage + readVoltage[9:0]));
                    address <= writeAdr - (switch[4] ? (intensity + 1'b1) << 8 : 13'h200);
                end 
                10'h2: begin        // add chorus 1 signal (if on)
                    if (switch[2])  sumVoltage <= (readVoltage[10] ? 
                        (sumVoltage - readVoltage[9:1]) : (sumVoltage + readVoltage[9:1]));
                    address <= writeAdr - (switch[4] ? 
                        ((intensity + 1'b1) << 8) + ((intensity + 1'b1) << 7) : 13'h300);
                end
                10'h3: begin        // add chorus 2 signal (if on)
                    if (switch[2])  sumVoltage <= (readVoltage[10] ? 
                        (sumVoltage - readVoltage[9:1]) : (sumVoltage + readVoltage[9:1]));
                    address <= writeAdr - (switch[4] ? (intensity + 1'b1) << 9 : 13'h400);
                end
                10'h4: begin        // add chorus 3 signal (if on)
                    if (switch[2])  sumVoltage <= (readVoltage[10] ? 
                        (sumVoltage - readVoltage[9:1]) : (sumVoltage + readVoltage[9:1]));
                    address <= writeAdr;
                end 
            endcase
        end
    end

    always_comb begin
        // Extend input voltages to 15 bits
        sampleExt = sampleVoltage;
        offsetExt = offset;

        // Remove offset from sample voltage
        offsetVoltage = sampleExt - offsetExt;

        // Absolute value of sumVoltage
        if (sumVoltage[15])     sumVoltageAbs = -sumVoltage;
        else                    sumVoltageAbs = sumVoltage;

        // Apply overdrive (if on) by amplifying voltage above a certain threshold
        if (switch[0] && sumVoltageAbs > 8'h1F)
            if (switch[4])  overdriven = sumVoltageAbs << intensity;
            else            overdriven = sumVoltageAbs << 2;
        else                overdriven = sumVoltageAbs;

        // Calculate threshold of saturation (lower if overdriven)
        if (switch[0])
            if (switch[4])  threshold = (intensity << 6) - 1'b1 + 16'h7F;
            else            threshold = 16'hFF;
        else                threshold = 16'h3FF;
        
        // Saturate signal at calculated threshold
        if (overdriven > threshold)     saturated = threshold[9:0];
        else                            saturated = overdriven[9:0];

        // Apply solo effect (if on) by filtering voltages below a threshold and inverting
        // Also apply repeater effect (if on)
        if (switch[3])
            if (saturated < 4'hF || (switch[4] && repCounter[15] && intensity > 4'h1))  
                    sendVoltageMag = 1'b0;
            else    sendVoltageMag = (-saturated) >> 1;
        else        sendVoltageMag = saturated;

        // Construct sendVoltage as sign-magnitude
        sendVoltage = {sumVoltage[15], sendVoltageMag};

        // Convert offsetVoltage to sign-magnitude to store in ring buffer
        if(offsetVoltage[15])   writeVoltage = {1'b1, -offsetVoltage[9:0]};
        else                    writeVoltage = {1'b0, offsetVoltage[9:0]};
    end
endmodule
