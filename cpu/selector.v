module selector #(parameter OPTIONS = 3, parameter WIDTH = 31)
    (input [0 : OPTIONS - 1] controls,
     input [0 : OPTIONS * WIDTH - 1] values,
     output [WIDTH - 1:0] out);

endmodule
