module sevensegment(
  input [3:0] nIn,
  output reg [6:0] ssOut
  );

  always @(nIn)
    case (nIn)
      4'h0: ssOut = ~7'b0111111;
      4'h1: ssOut = ~7'b0000110;
      4'h2: ssOut = ~7'b1011011;
      4'h3: ssOut = ~7'b1001111;
      4'h4: ssOut = ~7'b1100110;
      4'h5: ssOut = ~7'b1101101;
      4'h6: ssOut = ~7'b1111101;
      4'h7: ssOut = ~7'b0000111;
      4'h8: ssOut = ~7'b1111111;
      4'h9: ssOut = ~7'b1100111;
      4'hA: ssOut = ~7'b1110111;
      4'hB: ssOut = ~7'b1111100;
      4'hC: ssOut = ~7'b0111001;
      4'hD: ssOut = ~7'b1011110;
      4'hE: ssOut = ~7'b1111001;
      4'hF: ssOut = ~7'b1110001;
      default: ssOut = ~7'b1001001;
    endcase
endmodule
