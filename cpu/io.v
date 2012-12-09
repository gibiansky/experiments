module io(input clock,
          input reset,
          input LightLED,
          input LightSevenSegment,
          input ReadSwitch,
          input [3:0] KeySwitches,
          input [9:0] ToggleSwitches,
          input [31:0] control,
          input [31:0] value,
      
          output reg [7:0] Green,
          output reg [9:0] Red,
          output [6:0] SevenSegment0,
          output [6:0] SevenSegment1,
          output [6:0] SevenSegment2,
          output [6:0] SevenSegment3,
          output reg SwitchValue
      );

reg [3:0] RegNum0, RegNum1, RegNum2, RegNum3;

sevensegment a(RegNum0, SevenSegment0);
sevensegment b(RegNum1, SevenSegment1);
sevensegment c(RegNum2, SevenSegment2);
sevensegment d(RegNum3, SevenSegment3);

always @(posedge clock, posedge reset) begin
    // Turn off LEDs by default
    if (reset) begin
        Green <= 8'd0;
        Red <= 10'd0;
        RegNum0 <= 4'd0;
        RegNum1 <= 4'd0;
        RegNum2 <= 4'd0;
        RegNum3 <= 4'd0;
    end else if (LightLED) begin
        if (control >= 0 && control < 10)
            Red[control] <= (value == 0 ? 1'b0 : 1'b1);
        else if (control >= 10 && control < 18)
            Green[control - 10] <= (value == 0 ? 1'b0 : 1'b1);
    end else if (LightSevenSegment) begin
        if (control == 0)
            RegNum0 <= value[3:0];
        else if (control == 1)
            RegNum1 <= value[3:0];
        else if (control == 2)
            RegNum2 <= value[3:0];
        else if (control == 3)
            RegNum3 <= value[3:0];
    end
end

always @(posedge clock)
    if (ReadSwitch) begin
        if (value >= 0 && value <= 9)
            SwitchValue <= ToggleSwitches[value];
        else if (value < 14)
            SwitchValue <= KeySwitches[value - 10];
    end

endmodule
