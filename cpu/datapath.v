module datapath(input clock, 
                input reset,

                // Control flags
                input ReadInstructionPtr,
                input RegWrite,
                input MemWrite,
                input MemAddrInRegVsAluOut,
                input AluUseImmediateVsReg,
                input AluIncrInstrPtr,
                input RegWriteMemVsAlu,
                input RegBDestVsSourceReg,
                input RegWriteUseRegB,
                input RegWriteImmediate,
                input MemWriteByte,
                input RegAUseSourceVsDest,
                input RegWriteToOutReg,
                input RegWriteIfTrue,
                input RegWriteIfFalse,
                input ReadSwitch,
                input Switch,

                // Control values
                input [4:0] SourceReg,
                input [4:0] DestReg,
                input [3:0] AluControl,
                input [31:0] Immediate,

                // Outputs to controller
                output [31:0] out_mem_temp,
                output [31:0] RegisterFirstOut,
                output [31:0] RegisterSecondOut,
                output ready_mem_temp,
                output finished_memwrite
            );

// Register file ports
wire [4:0] addr_read_reg_a, addr_read_reg_b, addr_write_reg;
wire [31:0] data_write_reg;
wire [31:0] out_reg_a, out_reg_b;
wire out_zero;

assign RegisterFirstOut = out_reg_a;
assign RegisterSecondOut = out_reg_b;

// Constant register for instruction pointer
parameter CONST_OUT = 5'd12;
parameter CONST_IP = 5'd10;
wire [4:0] const_ip = CONST_IP;
wire [4:0] const_out = CONST_OUT;

// Memory ports
wire [31:0] addr_read_mem, addr_write_mem, data_write_mem;
wire [31:0] out_mem;
wire ready_mem;

// Alu ports
wire [31:0] src_alu_a, src_alu_b;
wire [31:0] out_alu;

// Constant bytes in a word
wire [31:0] word_length = 32'd4;

// Register file inputs
threemux #(5) read_reg_a_mux(ReadInstructionPtr, RegAUseSourceVsDest, 
    const_ip, SourceReg, DestReg, addr_read_reg_a);

twomux #(5) read_reg_b_mux(RegBDestVsSourceReg, DestReg, SourceReg, addr_read_reg_b);
fourmux #(5) incr_instr_mux(RegWriteToOutReg & AluUseImmediateVsReg, RegWriteToOutReg, ReadInstructionPtr, 
    const_out, Immediate[4:0], const_ip, DestReg, addr_write_reg);

wire [31:0] data_write_reg_temp;
fourmux reg_write_mux(RegWriteImmediate, RegWriteUseRegB, RegWriteMemVsAlu,
    Immediate, out_reg_b, out_mem, out_alu, data_write_reg_temp);
twomux reg_write_mux2(ReadSwitch, Switch == 0 ? 32'd0 : 32'd1, data_write_reg_temp,
    data_write_reg);

// Three-ported register file
wire write_to_reg = (RegWriteIfTrue & (out_zero == 0)) |
                    (RegWriteIfFalse & (out_zero == 1)) | RegWrite;
regfile registers(clock, reset,
                  addr_read_reg_a, addr_read_reg_b,
                  addr_write_reg, write_to_reg, data_write_reg,
                  out_reg_a, out_reg_b, out_zero);

// Memory inputs
twomux mem_input_mux(MemAddrInRegVsAluOut, out_reg_a, out_alu, addr_read_mem);
assign addr_write_mem = out_alu;
assign data_write_mem = out_reg_a;

// Two-ported memory with an access flip-flop
memory mem(clock, reset,
           addr_read_mem, addr_write_mem,
           MemWrite, data_write_mem, MemWriteByte,
           out_mem_temp, ready_mem_temp, finished_memwrite);
flipflop memflop(clock, reset, out_mem_temp, out_mem);
flag memready(clock, reset, ready_mem_temp, ready_mem);

// ALU inputs
twomux src_a_mux(AluUseImmediateVsReg, Immediate, out_reg_a, src_alu_a);
twomux src_b_mux(AluIncrInstrPtr, word_length, out_reg_b, src_alu_b);

// Arithmetic and logic
alu alu(src_alu_a, src_alu_b, AluControl, out_alu);

/*
integer ii;
integer debug = 1;
always @ (negedge clock)
    if (debug != 0 && $time >= 0) begin
    $display("\n---\nNegative Data Path:");
    for (ii = 0; ii < 13; ii = ii + 1)
        $display("Registers: %d -> %h", ii, registers.storage[ii]);
    for (ii = 0; ii < 5; ii = ii + 1)
        $display("Memory: %d -> %h", ii, mem.storage[ii]);
    $display("\nSourceReg: %d", SourceReg);
    $display("DestReg: %d", DestReg);
    $display("RegA: %d", addr_read_reg_a);
    $display("RegB: %d", addr_read_reg_b);
    $display("Register Outputs: %d, %d", RegisterFirstOut, RegisterSecondOut);
    $display("Controls: %b", 
        {ReadInstructionPtr,
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
        ReadSwitch}
    );
    $display("Switch: %b", Switch);
    $display("RegWriteIfTrueCond: %b", (RegWriteIfTrue & (out_zero == 0)));
    $display("RegWriteIfFalseCond: %b", (RegWriteIfFalse & (out_zero == 1)));
    $display("RegWrite: %b", RegWrite);
    $display("TrueRegwrite: %b", write_to_reg);
    $display("RegWriteData: %h", data_write_reg);
    $display("MemAddr: %h", addr_read_mem);
    $display("MemOutTemp: %h", out_mem_temp);
    $display("MemOut: %h", out_mem);
    $display("AluSrcA: %h", src_alu_a);
    $display("AluSrcB: %h", src_alu_b);
    $display("AluOut: %h", out_alu);
    $display("AluControl: %h", AluControl);
    $display("End\n---\n");

    if ($time >= 510)
        $stop;
end
*/

endmodule
