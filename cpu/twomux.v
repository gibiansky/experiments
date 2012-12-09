module twomux #(parameter WIDTH = 32)
            (input control,
             input [WIDTH - 1:0] first,
             input [WIDTH - 1:0] second,
             output [WIDTH - 1:0] out);

assign out = control ? first : second;

endmodule
