module tester;

// Clock and reset pins
reg clock;
reg reset;

// Outputs and inputs from the FPGA
reg [3:0] Keys = 4'd0;
reg [9:0] Toggles = 10'b1111111111;
wire [7:0] Green;
wire [9:0] Red;
wire [6:0] Hex0, Hex1, Hex2, Hex3;

// Test processor
processor dut(clock, reset, Keys, Toggles, Green, Red, Hex0, Hex1, Hex2, Hex3);

// Reset the processor
initial
begin
    // Start with clock on high
    clock = 1;

    reset <= 1;
    # 3;
    reset <= 0;
end

// Generate clock
always
begin
    clock <= 1;
    # 10;
    clock <= 0;
    # 10;
end

// Two elements:
// 1. Whether to verify (0 for no, 1 for yes)
// 2. After how many cycles to verify
reg [7:0] verify[0:1];

// Expected results
reg [31:0] expected_memory[0:65536];
reg [31:0] expected_regfile[0:31];

// Load memory and register file contents
initial
begin
    $readmemh("tests/data/verify", verify);

    if (verify[0] != 0) begin
        $display("Verify: %d\nCycles: %d", verify[0], verify[1]);
        $readmemh("tests/data/memory.expected", expected_memory);
        $readmemh("tests/data/regfile.expected", expected_regfile);
        $readmemh("tests/data/regfile.test", dut.datapath.registers.storage);
        $readmemh("tests/data/memory.test", dut.datapath.mem.storage);
        $display("Loaded memory and registers.");
    end
end

integer cycles = 0;
integer index = 0;
integer broken = 0;
always @ (negedge clock)
begin
    if (cycles != 0 && cycles == verify[1]) begin
        for (index = 0; index < 32; index = index + 1) 
            if (expected_regfile[index] != dut.datapath.registers.storage[index])
            begin
                $display("Regfile does not match at index %d.", index);
                $display("Expected: %h --- Found: %h\n", expected_regfile[index],
                    dut.datapath.registers.storage[index]);
                broken = 1;
            end

        for (index = 0; index < 65536; index = index + 1) 
            if (expected_memory[index] != dut.datapath.mem.storage[index])
            begin
                $display("Memory does not match at address %h", index);
                $display("Expected: %h --- Found: %h\n", expected_memory[index],
                    dut.datapath.mem.storage[index]);
                broken = 1;
            end

        if (broken == 1)
            $display("Test Failed.");
        else
            $display("Success.");
        $finish;
    end

    $display("FPGA State:");
    $display("Keys: %b", Keys);
    $display("Toggles: %b", Toggles);
    $display("Green: %b", Green);
    $display("Red: %b", Red);
    $display("Hex: (0 %b) (1 %b) (2 %b) (3 %b)", Hex0, Hex1, Hex2, Hex3);
    
    cycles = cycles + 1;
end

endmodule
