module controller(input clock, 
                  input reset,

                  // Datapath input
                  input [31:0] instruction,
                  input ready_instruction,
                  input finished_memwrite,

                  // Control flags
                  output ReadInstructionPtr,
                  output RegWrite,
                  output MemWrite,
                  output MemAddrInRegVsAluOut,
                  output AluUseImmediateVsReg,
                  output AluIncrInstrPtr,
                  output RegWriteMemVsAlu,
                  output RegBDestVsSourceReg,
                  output RegWriteUseRegB,
                  output RegWriteImmediate,
                  output MemWriteByte,
                  output RegAUseSourceVsDest,
                  output RegWriteToOutReg,
                  output RegWriteIfTrue,
                  output RegWriteIfFalse,
                  output LightLED,
                  output LightSevenSegment,
                  output ReadSwitch,

                  // Control values
                  output reg [4:0] SourceReg,
                  output reg [4:0] DestReg,
                  output [3:0] AluControl,
                  output reg [31:0] Immediate
              );

// Control flag values
// Order as in parameter list
parameter CONTROL_READ_INSTRUCTION        = 18'b110101000000000000;
parameter CONTROL_READ_MEMORY             = 18'b000010000000000000;
parameter CONTROL_STORE_REGISTER          = 18'b010000100000000000;
parameter CONTROL_STORE_MEMORY            = 18'b001010010001000000;
parameter CONTROL_STORE_REG_FROM_REG      = 18'b010000001000000000;
parameter CONTROL_STORE_REG_FROM_CONST    = 18'b010000000100000000;
parameter CONTROL_READ_MEMORY_BYTE        = 18'b000010000010000000;
parameter CONTROL_STORE_MEMORY_BYTE       = 18'b001010010011000000;
parameter CONTROL_STORE_ALUCOMP_REG       = 18'b010000000000100000;
parameter CONTROL_STORE_ALUCOMP_CONST     = 18'b010010010000100000;
parameter CONTROL_JUMP                    = 18'b010010000000000000;
parameter CONTROL_JUMP_IF_TRUE            = 18'b000010000000010000;
parameter CONTROL_JUMP_IF_FALSE           = 18'b000010000000001000;
parameter CONTROL_JUMP_TO_REG             = 18'b010010000000000000;
parameter CONTROL_LIGHT_LED               = 18'b000000000000000100;
parameter CONTROL_LIGHT_NUMBER            = 18'b000000000000000010;
parameter CONTROL_READ_SWITCH             = 18'b010000000000000001;

// States
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

// Opcodes and specifier
parameter OPCODE_MOVE   = 3'd0;

parameter MOVE_REGTOREG          = 3'd0;
parameter MOVE_REGTOMEM          = 3'd1;
parameter MOVE_MEMTOREG          = 3'd2;
parameter MOVE_CONSTTOREG        = 3'd3;
parameter MOVE_BYTE_MEMTOREG     = 3'd4;
parameter MOVE_BYTE_REGTOMEM     = 3'd5;

parameter OPCODE_ARITHMETIC   = 3'd1;

parameter ALU_ADD_REG          = 3'd0;
parameter ALU_ADD_CONST        = 3'd1;
parameter ALU_SUB_REG          = 3'd2;
parameter ALU_SUB_CONST        = 3'd3;
parameter ALU_MUL_REG          = 3'd4;
parameter ALU_MUL_CONST        = 3'd5;
parameter ALU_DIV_REG          = 3'd6;
parameter ALU_DIV_CONST        = 3'd7;

parameter OPCODE_LOGICAL    = 3'd2;

parameter ALU_AND_REG             = 3'd0;
parameter ALU_OR_REG              = 3'd1;
parameter ALU_NEQ_REG             = 3'd2;
parameter ALU_NEQ_CONST           = 3'd3;
parameter ALU_EQ_REG              = 3'd4;
parameter ALU_EQ_CONST            = 3'd5;
parameter ALU_NOT                 = 3'd6;
parameter ALU_NEGATE              = 3'd7;

parameter OPCODE_COMPARISON = 3'd3;

parameter ALU_LT_REG             = 3'd0;
parameter ALU_LT_CONST           = 3'd1;
parameter ALU_LTE_REG            = 3'd2;
parameter ALU_LTE_CONST          = 3'd3;
parameter ALU_GT_REG             = 3'd4;
parameter ALU_GT_CONST           = 3'd5;
parameter ALU_GTE_REG            = 3'd6;
parameter ALU_GTE_CONST          = 3'd7;

parameter OPCODE_JUMP = 3'd4;

parameter JUMP_UNCONDITIONAL    = 3'd0;
parameter JUMP_IF_TRUE          = 3'd1;
parameter JUMP_IF_FALSE         = 3'd2;
parameter JUMP_TO_REG           = 3'd3;

parameter OPCODE_SYSTEM = 3'd5;

parameter SYSTEM_LED             = 3'd0;
parameter SYSTEM_SEVENSEGMENT    = 3'd1;
parameter SYSTEM_READ_SWITCH     = 3'd2;


// Decode current state into control flag values
reg [17:0] controls;
always @ (*)
    case (state)
        STATE_READ_INSTRUCTION:     controls = CONTROL_READ_INSTRUCTION;
        STATE_READ_MEMORY:          controls = CONTROL_READ_MEMORY;
        STATE_STORE_REGISTER:       controls = CONTROL_STORE_REGISTER;
        STATE_STORE_MEMORY:         controls = CONTROL_STORE_MEMORY;
        STATE_STORE_REG_FROM_REG:   controls = CONTROL_STORE_REG_FROM_REG;
        STATE_STORE_REG_FROM_CONST: controls = CONTROL_STORE_REG_FROM_CONST;
        STATE_STORE_MEMORY_BYTE:    controls = CONTROL_STORE_MEMORY_BYTE;
        STATE_READ_MEMORY_BYTE:     controls = CONTROL_READ_MEMORY_BYTE;

        STATE_STORE_ADD_REG:        controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_SUB_REG:        controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_MUL_REG:        controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_DIV_REG:        controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_ADD_CONST:      controls = CONTROL_STORE_ALUCOMP_CONST;
        STATE_STORE_SUB_CONST:      controls = CONTROL_STORE_ALUCOMP_CONST;
        STATE_STORE_MUL_CONST:      controls = CONTROL_STORE_ALUCOMP_CONST;
        STATE_STORE_DIV_CONST:      controls = CONTROL_STORE_ALUCOMP_CONST;

        STATE_STORE_AND_REG:        controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_OR_REG:         controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_EQ_REG:         controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_NEQ_REG:        controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_NEQ_CONST:      controls = CONTROL_STORE_ALUCOMP_CONST;
        STATE_STORE_EQ_CONST:       controls = CONTROL_STORE_ALUCOMP_CONST;

        STATE_STORE_NOT:            controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_NEGATE:         controls = CONTROL_STORE_ALUCOMP_REG;

        STATE_STORE_LT_REG:        controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_LTE_REG:       controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_GT_REG:        controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_GTE_REG:       controls = CONTROL_STORE_ALUCOMP_REG;
        STATE_STORE_LT_CONST:      controls = CONTROL_STORE_ALUCOMP_CONST;
        STATE_STORE_LTE_CONST:     controls = CONTROL_STORE_ALUCOMP_CONST;
        STATE_STORE_GT_CONST:      controls = CONTROL_STORE_ALUCOMP_CONST;
        STATE_STORE_GTE_CONST:     controls = CONTROL_STORE_ALUCOMP_CONST;

        STATE_STORE_JUMP:           controls = CONTROL_JUMP;
        STATE_STORE_JUMP_IF_TRUE:   controls = CONTROL_JUMP_IF_TRUE;
        STATE_STORE_JUMP_IF_FALSE:  controls = CONTROL_JUMP_IF_FALSE;
        STATE_STORE_JUMP_TO_REG:    controls = CONTROL_JUMP_TO_REG;

        STATE_LIGHT_LED:            controls = CONTROL_LIGHT_LED;
        STATE_LIGHT_NUMBER:         controls = CONTROL_LIGHT_NUMBER;
        STATE_READ_SWITCH:          controls = CONTROL_READ_SWITCH;

        default: begin
            $display("Broken state.");
            $finish;
            controls = 18'bx;
        end
    endcase

// Output control flag values individually
assign {ReadInstructionPtr,
        RegWrite,
        MemWrite,
        MemAddrInRegVsAluOut,
        AluUseImmediateVsReg,
        AluIncrInstrPtr,
        RegWriteMemVsAlu,
        RegBDestVsSourceReg,
        RegWriteUseRegB,
        RegWriteImmediate,
        MemWriteByte,
        RegAUseSourceVsDest,
        RegWriteToOutReg,
        RegWriteIfTrue,
        RegWriteIfFalse,
        LightLED,
        LightSevenSegment,
        ReadSwitch} = controls;

// Internal storage
reg [7:0] state;

// Storage for instruction bits
reg [2:0] opcode;
reg [2:0] specifier;

// Alu Out register
parameter CONST_OUT = 5'd12;
parameter CONST_IP = 5'd10;

// Alu control
aludecoder aludec(state, opcode, specifier, AluControl);

// Change states
always @ (posedge clock, posedge reset)
if (reset) begin
	// Reset to reading instructions
    state = STATE_READ_INSTRUCTION;
end else begin
    case (state)
        STATE_READ_INSTRUCTION:
        begin
            // Wait for memory to be available
            if (ready_instruction) begin
                // Deconstruct 32-bit instruction into parts and store
                opcode  = instruction[31:29];
                specifier = instruction[28:26];
                if (opcode != OPCODE_JUMP) begin
                    DestReg = instruction[25:21];
                    SourceReg = instruction[20:16];

                    // Sign extend the immediate
                    Immediate = { { (16){instruction[15]} }, instruction[15:0]};
                end else begin
                    if (specifier == JUMP_TO_REG) begin
                        DestReg = CONST_IP;
                        SourceReg = instruction[25:21];
                        Immediate = 32'd0;
                    end else begin
                        DestReg = CONST_IP;
                        SourceReg = CONST_IP;

                        // Sign extend the jump offset
                        Immediate = { { (11){instruction[20]} }, instruction[20:0]};
                    end
                end

                /*
                $display("\n---\nChanged Instruction:");
                $display("instruction %h", instruction, ready_instruction);
                $display("opcode %d specifier %d", opcode, specifier);
                $display("End\n---\n");
                */

                case (opcode)
                    OPCODE_MOVE:
                        case (specifier)
                            MOVE_MEMTOREG: state = STATE_READ_MEMORY;
                            MOVE_REGTOMEM: state = STATE_STORE_MEMORY;
                            MOVE_REGTOREG: state = STATE_STORE_REG_FROM_REG;
                            MOVE_CONSTTOREG: state = STATE_STORE_REG_FROM_CONST;

                            MOVE_BYTE_MEMTOREG: state = STATE_READ_MEMORY_BYTE;
                            MOVE_BYTE_REGTOMEM: state = STATE_STORE_MEMORY_BYTE;
                            default: begin
                                $display("Broken OPCODE_MOVE.");
                                $display("Specifier: %d", specifier);
                                $finish;
                                state = STATE_UNDEFINED;
                            end
                        endcase

                    OPCODE_ARITHMETIC:
                        case (specifier)
                            ALU_ADD_REG: state = STATE_STORE_ADD_REG;
                            ALU_SUB_REG: state = STATE_STORE_SUB_REG;
                            ALU_MUL_REG: state = STATE_STORE_MUL_REG;
                            ALU_DIV_REG: state = STATE_STORE_DIV_REG;
                            ALU_ADD_CONST: state = STATE_STORE_ADD_CONST;
                            ALU_SUB_CONST: state = STATE_STORE_SUB_CONST;
                            ALU_MUL_CONST: state = STATE_STORE_MUL_CONST;
                            ALU_DIV_CONST: state = STATE_STORE_DIV_CONST;
                            default: begin
                                $display("Broken OPCODE_ARITHMETIC.");
                                $finish;
                                state = STATE_UNDEFINED;
                            end
                        endcase

                    OPCODE_LOGICAL:
                        case (specifier)
                            ALU_AND_REG:    state = STATE_STORE_AND_REG;
                            ALU_OR_REG:     state = STATE_STORE_OR_REG;
                            ALU_NEQ_REG:    state = STATE_STORE_NEQ_REG;
                            ALU_NEQ_CONST:  state = STATE_STORE_NEQ_CONST;
                            ALU_EQ_REG:     state = STATE_STORE_EQ_REG;
                            ALU_EQ_CONST:   state = STATE_STORE_EQ_CONST;
                            ALU_NOT:        state = STATE_STORE_NOT;
                            ALU_NEGATE:     state = STATE_STORE_NEGATE;

                            default: begin
                                $display("Broken OPCODE_LOGICAL.");
                                $finish;
                                state = STATE_UNDEFINED;
                            end
                        endcase

                    OPCODE_COMPARISON:
                        case (specifier)
                            ALU_LT_REG:     state = STATE_STORE_LT_REG;
                            ALU_LT_CONST:   state = STATE_STORE_LT_CONST;
                            ALU_LTE_REG:    state = STATE_STORE_LTE_REG;
                            ALU_LTE_CONST:  state = STATE_STORE_LTE_CONST;
                            ALU_GT_REG:     state = STATE_STORE_GT_REG;
                            ALU_GT_CONST:   state = STATE_STORE_GT_CONST;
                            ALU_GTE_REG:    state = STATE_STORE_GTE_REG;
                            ALU_GTE_CONST:  state = STATE_STORE_GTE_CONST;
                            default: begin
                                $display("Broken OPCODE_COMPARISON.");
                                $finish;
                                state = STATE_UNDEFINED;
                            end
                        endcase

                    OPCODE_JUMP:
                        case (specifier)
                            JUMP_UNCONDITIONAL: state = STATE_STORE_JUMP;
                            JUMP_IF_TRUE:       state = STATE_STORE_JUMP_IF_TRUE;
                            JUMP_IF_FALSE:      state = STATE_STORE_JUMP_IF_FALSE;
                            JUMP_TO_REG:        state = STATE_STORE_JUMP_TO_REG;

                            default: begin
                                $display("Broken OPCODE_JUMP.");
                                $finish;
                                state = STATE_UNDEFINED;
                            end
                        endcase

                    OPCODE_SYSTEM:
                        case (specifier)
                            SYSTEM_LED: state = STATE_LIGHT_LED;
                            SYSTEM_SEVENSEGMENT: state = STATE_LIGHT_NUMBER;
                            SYSTEM_READ_SWITCH: state = STATE_READ_SWITCH;

                            default: begin
                                $display("Broken OPCODE_SYSTEM.");
                                $finish;
                                state = STATE_UNDEFINED;
                            end
                        endcase
                    default: begin
                        $display("Broken opcode.");
                        $display("Opcode (%b)", opcode);
                        $finish;
                        state = STATE_UNDEFINED;
                    end
                endcase
            end

        end

        // Only need to add additional info if this isn't the last
        // instruction, or if for whatever reason we shouldn't just jump
        // to reading the next instruction after this clock cycle
        STATE_READ_MEMORY:
            // Wait for memory to be available before writing
            if (ready_instruction)
                state = STATE_STORE_REGISTER;
            
        STATE_STORE_MEMORY:
            if (finished_memwrite)
                state = STATE_READ_INSTRUCTION;

        STATE_READ_MEMORY_BYTE:
            // Wait for memory to be available before writing
            if (ready_instruction)
                state = STATE_STORE_REGISTER;

        STATE_STORE_MEMORY_BYTE:
            if (finished_memwrite)
                state = STATE_READ_INSTRUCTION;

        default:
            state = STATE_READ_INSTRUCTION;
    endcase

    /*
    $display("\n---\nChanged Controller:");
    $display("Controller state ind: %d", state);
    $display("Output: SrcReg(%d) DestReg(%d) ALU(%b) Immediate(%h)",
        SourceReg, DestReg, AluControl, Immediate);
    $display("End\n---\n");
    */
end

endmodule
