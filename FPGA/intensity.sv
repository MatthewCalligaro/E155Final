// Name: Giselle Serate
// Email: gserate@g.hmc.edu
// Date: 11/30/2018
// Summary: Converts a measured distance into an intensity

module intensity(input logic [11:0] average,    // average distance detected by sensor    
                 output logic [3:0] intensity); // 9-level intensity corresponding to distance

    always_comb begin
        if      (average > 12'h900)     intensity = 4'h0;   // Farthest = least intense. 
        else if (average > 12'h800)     intensity = 4'h1; 
        else if (average > 12'h700)     intensity = 4'h2;
        else if (average > 12'h600)     intensity = 4'h3;
        else if (average > 12'h500)     intensity = 4'h4;
        else if (average > 12'h400)     intensity = 4'h5;
        else if (average > 12'h300)     intensity = 4'h6;
        else if (average > 12'h200)     intensity = 4'h7;
        else                            intensity = 4'h8;   // Closest = most intense.
    end
endmodule
