/*
* RAM array
*/
module memory(input clock, reset,
              input [31:0] addr_read,
              input [31:0] addr_write,
              input en_write,
              input [31:0] data_write,
              input write_byte,
              output [31:0] out,
              output ready,
              output written);

wire [31:0] out_ram;

// Memory interface
// Force word-aligned reads by ignoring the last 2 bits
wire [31:0] empty = 32'b0;
wire [31:0] discard;
wire disabled = 1'b0;
ram mem(empty, data_write, addr_read[31:2], addr_write[31:2], 
	disabled, en_write, clock, out_ram, discard);
	
assign out = (addr_read[31:2] < size) ? storage[addr_read[31:2]] : out_ram;

// Upon reset, initialize beginning of RAM
reg [31:0] storage[400:0];
reg [5:0] size = 6'd0;

always @ (posedge reset)
	if (reset) begin
		// Load program
		size <= 17;
		
		// Program #1
      // Turn all LEDs on, then off. Then count.
      storage[0] <= 32'd201326592;
      storage[1] <= 32'd203423745;
      storage[2] <= 32'd0;
      storage[3] <= -32'd1610547200;
      storage[4] <= 32'd536936448;
      storage[5] <= 32'd2080374786;
      storage[6] <= -32'd2078277648;
      storage[7] <= 32'd205520896;
      storage[8] <= 32'd0;
      storage[9] <= 32'd671154176;
      storage[10] <= -32'd1610481664;
      storage[11] <= 32'd1677721600;
      storage[12] <= -32'd2078277648;
      storage[13] <= 32'd0;
      storage[14] <= -32'd1539309568;
      storage[15] <= 32'd536936448;
      storage[16] <= -32'd2145386508;

      // Program #2
      // Turn one LED on and off. Then count.
      /*
      storage[0] <= 32'd201326592;
      storage[1] <= 32'd203423745;
      storage[2] <= 32'd205520896;
      storage[3] <= -32'd1610547200;
      storage[4] <= -32'd1610612736;
      storage[5] <= 32'd0;
      storage[6] <= -32'd1539309568;
      storage[7] <= 32'd536936448;
      storage[8] <= -32'd2145386508;
      */
	end
	
	 
assign ready = 1;
assign written = 1;

endmodule
