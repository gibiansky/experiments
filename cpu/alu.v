module alu(input [31:0] src_a,
           input [31:0] src_b,
           input [3:0] control,
           output reg [31:0] out);

parameter ALU_ADD       = 4'd0;
parameter ALU_SUB       = 4'd1;
parameter ALU_MUL       = 4'd2;
parameter ALU_DIV       = 4'd3;
parameter ALU_DIV_SWAP  = 4'd4;
parameter ALU_AND       = 4'd5;
parameter ALU_OR        = 4'd6;
parameter ALU_NOT       = 4'd7;
parameter ALU_NEGATE    = 4'd8;
parameter ALU_LT        = 4'd9;
parameter ALU_LTE       = 4'd10;
parameter ALU_GT        = 4'd11;
parameter ALU_GTE       = 4'd12;
parameter ALU_EQ        = 4'd13;
parameter ALU_NEQ       = 4'd14;

always @ (*)
    case (control)
        ALU_ADD: out = src_a + src_b;
        ALU_SUB: out = src_a - src_b;
        ALU_MUL: out = src_a * src_b;
        ALU_DIV: out = src_a / src_b;
        ALU_DIV_SWAP: out = src_b / src_a;
        ALU_AND:    out = src_a & src_b; 
        ALU_OR:     out = src_a | src_b;
        ALU_NOT:    out = (src_a == 32'd0) ? 32'd1 : 32'd0;
        ALU_NEGATE: out = ~src_a;
        ALU_LT:     out = (src_a < src_b) ? 32'd1 : 32'd0;
        ALU_LTE:    out = (src_a <= src_b) ? 32'd1 : 32'd0;
        ALU_GT:     out = (src_a > src_b) ? 32'd1 : 32'd0;
        ALU_GTE:    out = (src_a >= src_b) ? 32'd1 : 32'd0;
        ALU_EQ:     out = (src_a == src_b) ? 32'd1 : 32'd0;
        ALU_NEQ:    out = (src_a != src_b) ? 32'd1 : 32'd0;

        default: out = 32'b0;
    endcase

endmodule
