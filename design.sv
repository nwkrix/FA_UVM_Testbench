// Code your design here
interface dut_if;
  logic clk;
  logic reset;
  logic [7:0] A, B; 
  logic C_in;
  logic [7:0] Sum;
  logic C_out;
  
endinterface

module FullAdder(
  dut_if dif
);
  always@(dif.A,dif.B,dif.C_in)
  begin
      {dif.C_out,dif.Sum} <= dif.A + dif.B + dif.C_in;
  end
  
endmodule