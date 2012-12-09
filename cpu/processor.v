module processor(
	input clock,
	input reset,
	input [3:0] Keys,
	input [9:0] Toggles,
	output [7:0] Green,
	output [9:0] Red,
	output [6:0] Hex0, Hex1, Hex2, Hex3
);

// Memory
wire [31:0] out_mem;
wire ready_mem, finished_memwrite;

// Control flags
wire ReadInstructionPtr,
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
     ReadSwitch;

wire Switch;

// Control values
wire [4:0] SourceReg, DestReg;
wire [3:0] AluControl;
wire [31:0] Immediate;

wire [31:0] reg_a, reg_b;

controller controller(clock, reset,
                      out_mem,
                      ready_mem,
                      finished_memwrite,

                      ReadInstructionPtr,
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
                      ReadSwitch,

                      SourceReg,
                      DestReg,
                      AluControl,
                      Immediate
                    );

datapath datapath(clock, reset,

                  ReadInstructionPtr,
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
                  ReadSwitch,
                  Switch,

                  SourceReg,
                  DestReg,
                  AluControl,
                  Immediate,
                  out_mem,
                  reg_a,
                  reg_b,
                  ready_mem,
                  finished_memwrite
              );

io io(
    clock,
    reset,
    LightLED,
    LightSevenSegment,
    ReadSwitch,
    Keys,
    Toggles,
    reg_a,
    reg_b,

    Green,
    Red,
    Hex0,
    Hex1,
    Hex2,
    Hex3,
    Switch
    );

endmodule
