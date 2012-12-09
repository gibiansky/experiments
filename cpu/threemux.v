// Cascading mux
module threemux #(parameter WIDTH = 32)
            (input control1, control2,
             input [WIDTH - 1:0] first,
             input [WIDTH - 1:0] second,
             input [WIDTH - 1:0] third,
             output [WIDTH - 1:0] out);

assign out = control1 ? first : control2 ? second : third;

endmodule
