/*
* Resetabble 32-bit flip-flop
*/
module flipflop(input clock, reset,
                input [31:0] in,
                output reg [31:0] out);

always @ (posedge clock, posedge reset)
    if (reset)
        out <= 32'b0;
    else
        out <= in;

endmodule
