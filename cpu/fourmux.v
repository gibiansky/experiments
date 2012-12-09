// Doubly cascading mux
module fourmux #(parameter WIDTH = 32)
            (input control1, control2, control3,
             input [WIDTH - 1:0] first,
             input [WIDTH - 1:0] second,
             input [WIDTH - 1:0] third,
             input [WIDTH - 1:0] fourth,
             output [WIDTH - 1:0] out);

assign out = control1 ? first : control2 ? second : control3 ? third : fourth;

endmodule
