/*
* Resetabble 1-bit flip-flop
*/
module flag(input clock, reset,
            input in,
            output reg out);

always @ (posedge clock, posedge reset)
    if (reset)
        out <= 0;
    else
        out <= in;

endmodule
