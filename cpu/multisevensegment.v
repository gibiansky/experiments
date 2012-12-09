module multisevensegment(
	input [31:0] value,
	output [6:0] first,
	output [6:0] second,
	output [6:0] third,
	output [6:0] fourth);

wire [3:0] ones = value % 10;
wire [3:0] tens = (value % 100) / 10;
wire [3:0] hundreds = (value % 1000) / 100;
wire [3:0] thousands = (value % 10000) / 1000;
	
sevensegment a(ones, first);
sevensegment b(tens, second);
sevensegment c(hundreds, third);
sevensegment d(thousands, fourth);
	
endmodule
