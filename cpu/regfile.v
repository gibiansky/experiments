module regfile(input clock, reset,
               input [4:0] addr_read_a,
               input [4:0] addr_read_b,
               input [4:0] addr_write,
               input en_write,
               input [31:0] data_write,
               output [31:0] out_a,
               output [31:0] out_b,
               output out_zero);

// Make sure this matches controller.v
parameter CONST_OUT = 5'd12;

reg [31:0] storage[0:31];

always @ (posedge clock, posedge reset)
begin
    if (reset) begin
        storage[0] <= 32'd0;
        storage[1] <= 32'd0;
        storage[2] <= 32'd0;
        storage[3] <= 32'd0;
        storage[4] <= 32'd0;
        storage[5] <= 32'd0;
        storage[6] <= 32'd0;
        storage[7] <= 32'd0;
        storage[8] <= 32'd0;
        storage[9] <= 32'd0;
        storage[10] <= 32'd0;
        storage[11] <= 32'd0;
        storage[12] <= 32'd0;
        storage[13] <= 32'd0;
        storage[14] <= 32'd0;
        storage[15] <= 32'd0;
        storage[16] <= 32'd0;
        storage[17] <= 32'd0;
        storage[18] <= 32'd0;
        storage[19] <= 32'd0;
        storage[20] <= 32'd0;
        storage[21] <= 32'd0;
        storage[22] <= 32'd0;
        storage[23] <= 32'd0;
        storage[24] <= 32'd0;
        storage[25] <= 32'd0;
        storage[26] <= 32'd0;
        storage[27] <= 32'd0;
        storage[28] <= 32'd0;
        storage[29] <= 32'd0;
        storage[30] <= 32'd0;
        storage[31] <= 32'd0;
    end else if (en_write)
        storage[addr_write] = data_write;
end

assign out_a = storage[addr_read_a];
assign out_b = storage[addr_read_b];
assign out_zero = (storage[CONST_OUT] == 32'd0);

endmodule
