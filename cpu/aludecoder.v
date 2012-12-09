module aludecoder(input [7:0] controller_state,
                  input [2:0] opcode,
                  input [2:0] specifier,
                  output reg [3:0] control);

// Controller states
// These must be the same as in controller.v
parameter STATE_UNDEFINED                 = 8'd0;
parameter STATE_READ_INSTRUCTION          = 8'd1;
parameter STATE_READ_MEMORY               = 8'd2;
parameter STATE_STORE_REGISTER            = 8'd3;
parameter STATE_STORE_MEMORY              = 8'd4;
parameter STATE_STORE_REG_FROM_REG        = 8'd6;
parameter STATE_STORE_REG_FROM_CONST      = 8'd7;
parameter STATE_STORE_MEMORY_BYTE         = 8'd8;
parameter STATE_READ_MEMORY_BYTE          = 8'd9;
parameter STATE_STORE_ADD_REG             = 8'd10;
parameter STATE_STORE_SUB_REG             = 8'd11;
parameter STATE_STORE_MUL_REG             = 8'd12;
parameter STATE_STORE_DIV_REG             = 8'd13;
parameter STATE_STORE_ADD_CONST           = 8'd14;
parameter STATE_STORE_SUB_CONST           = 8'd15;
parameter STATE_STORE_MUL_CONST           = 8'd16;
parameter STATE_STORE_DIV_CONST           = 8'd17;

parameter STATE_STORE_AND_REG             = 8'd18;
parameter STATE_STORE_OR_REG              = 8'd19;
parameter STATE_STORE_EQ_REG              = 8'd20;
parameter STATE_STORE_NEQ_REG             = 8'd21;
parameter STATE_STORE_NEQ_CONST           = 8'd22;
parameter STATE_STORE_EQ_CONST            = 8'd23;
parameter STATE_STORE_NOT                 = 8'd24;
parameter STATE_STORE_NEGATE              = 8'd25;

parameter STATE_STORE_LT_REG              = 8'd26;
parameter STATE_STORE_LTE_REG             = 8'd27;
parameter STATE_STORE_GT_REG              = 8'd28;
parameter STATE_STORE_GTE_REG             = 8'd29;
parameter STATE_STORE_LT_CONST            = 8'd30;
parameter STATE_STORE_LTE_CONST           = 8'd31;
parameter STATE_STORE_GT_CONST            = 8'd32;
parameter STATE_STORE_GTE_CONST           = 8'd33;

parameter STATE_STORE_JUMP                = 8'd34;
parameter STATE_STORE_JUMP_IF_TRUE        = 8'd35;
parameter STATE_STORE_JUMP_IF_FALSE       = 8'd36;
parameter STATE_STORE_JUMP_TO_REG         = 8'd37;

parameter STATE_LIGHT_LED                 = 8'd38;
parameter STATE_LIGHT_NUMBER              = 8'd39;
parameter STATE_READ_SWITCH               = 8'd40;

// ALU commands
// These must be the same as in alu.v
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
begin
    case (controller_state)
        STATE_READ_INSTRUCTION:
            control = ALU_ADD;
        STATE_READ_MEMORY:
            control = ALU_ADD;

        STATE_STORE_REGISTER:
            control = ALU_ADD;
        STATE_STORE_MEMORY:
            control = ALU_ADD;
        STATE_STORE_REG_FROM_REG:
            control = ALU_ADD;
        STATE_STORE_REG_FROM_CONST:
            control = ALU_ADD;
        STATE_STORE_MEMORY_BYTE:
            control = ALU_ADD;
        STATE_READ_MEMORY_BYTE:
            control = ALU_ADD;

        STATE_STORE_ADD_REG:
            control = ALU_ADD;
        STATE_STORE_SUB_REG:
            control = ALU_SUB;
        STATE_STORE_MUL_REG:
            control = ALU_MUL;
        STATE_STORE_DIV_REG:
            control = ALU_DIV;

        STATE_STORE_ADD_CONST:
            control = ALU_ADD;
        STATE_STORE_SUB_CONST:
            control = ALU_SUB;
        STATE_STORE_MUL_CONST:
            control = ALU_MUL;
        STATE_STORE_DIV_CONST:
            control = ALU_DIV_SWAP;


        STATE_STORE_AND_REG:
            control = ALU_AND;
        STATE_STORE_OR_REG:
            control = ALU_OR;
        STATE_STORE_EQ_REG:
            control = ALU_EQ;
        STATE_STORE_NEQ_REG:
            control = ALU_NEQ;
        STATE_STORE_NEQ_CONST:
            control = ALU_NEQ;
        STATE_STORE_EQ_CONST:
            control = ALU_EQ;
        STATE_STORE_NOT:
            control = ALU_NOT;
        STATE_STORE_NEGATE:
            control = ALU_NEGATE;

        STATE_STORE_LT_REG:
            control = ALU_LT;
        STATE_STORE_LT_CONST:
            control = ALU_LT;
        STATE_STORE_LTE_REG:
            control = ALU_LTE;
        STATE_STORE_LTE_CONST:
            control = ALU_LTE;
        STATE_STORE_GT_REG:
            control = ALU_GT;
        STATE_STORE_GT_CONST:
            control = ALU_GT;
        STATE_STORE_GTE_REG:
            control = ALU_GTE;
        STATE_STORE_GTE_CONST:
            control = ALU_GTE;

        STATE_STORE_JUMP:
            control = ALU_ADD;
        STATE_STORE_JUMP_IF_TRUE:
            control = ALU_ADD;
        STATE_STORE_JUMP_IF_FALSE:
            control = ALU_ADD;

        STATE_LIGHT_LED:
            control = ALU_ADD;
        STATE_LIGHT_NUMBER:
            control = ALU_ADD;
        STATE_READ_SWITCH:
            control = ALU_ADD;

        default: begin
            $display("Broken ALU.");
            $display("Controller state %d.", controller_state);
            $finish;
            control = ALU_ADD;
        end
    endcase
end

endmodule
