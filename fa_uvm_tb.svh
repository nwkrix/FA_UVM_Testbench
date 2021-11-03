`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 11/03/2021 07:57:20 PM
// Design Name: FULL ADDER -- UVM Testbench
// Project Name: FullAdder
//////////////////////////////////////////////////////////////////////////////////

`include "uvm_macros.svh"
import uvm_pkg::*;

module tb; // top_module
  
  dut_if intf(); 
  
  initial begin
    intf.clk = 1'b0;
    intf.reset = 1'b1;
    #5 intf.reset = 1'b0;
  end
  
  always #5 begin
    intf.clk <= ~intf.clk;
  end
 
  FullAdder dut(.dif(intf));
  
  initial begin
    // store interfaces in UVM Config database for access by sub-components
    uvm_config_db#(virtual dut_if)::set(null,"uvm_test_top","intf",intf); 
    run_test("Test");
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule //  top_module

class Seq_Item extends uvm_sequence_item; 
  `uvm_object_utils(Seq_Item)
  function new(string name = "Seq_Item");
    super.new(name);
  endfunction	
  rand bit [7:0] A, B;
  rand bit C_in;
  bit [7:0] Sum;
  bit C_out;
  virtual function string show_state();
    return $sformatf("A:=%0d, B:=%0d, C_in:=%0d, C_out:=%0d, Sum:=%0d",A,B,C_in,C_out,Sum);
  endfunction
endclass // Seq_Item extends uvm_sequence_item;

class Seq extends uvm_sequence #(Seq_Item);
  `uvm_object_utils(Seq)
  function new(string name = "Seq");
    super.new(name);
  endfunction
  
  Seq_Item req; 
  int unsigned ntime = 10;
  
  task body();    
    repeat(ntime) begin
      /* the macro "`uvm_do", does the following to the object req
          1) creates the sequence item req
          2) randomizes req
          3) calls start_item(), and then finish_item()  
      */
      `uvm_do(req);  
    end
  endtask  
endclass // Seq extends uvm_sequence #(Seq_Item)

class Seqr extends uvm_sequencer #(Seq_Item);
  `uvm_component_utils(Seqr)
  function new(string name = "Seqr",uvm_component parent = null);
    super.new(name,parent);
  endfunction
endclass // Seqr extends uvm_sequencer #(Seq_Item);

class Driver extends uvm_driver #(Seq_Item);
  `uvm_component_utils(Driver)
  function new(string name = "Driver",uvm_component parent = null);
    super.new(name,parent);
  endfunction

  virtual dut_if intf;
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(! uvm_config_db #(virtual dut_if)::get(null,"uvm_test_top","intf",intf)) 
      begin
        `uvm_error(get_type_name(),$sformatf("Interface not retrieved"))
      end
  endfunction

  Seq_Item rsp;
  
  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    fork
      forever begin
        seq_item_port.get_next_item(rsp);
        @(posedge intf.clk) begin
          wire_up(rsp);
        end
        seq_item_port.item_done();
      end
    join_any
  endtask

  virtual task wire_up(Seq_Item rsp);
    if(!intf.reset) begin
      intf.A 		  <= rsp.A;
      intf.B 		  <= rsp.B;
      intf.C_in   <= rsp.C_in;
    end else begin
      intf.A 		<= 8'b00000000;
      intf.B 		<= 8'b00000000;
      intf.C_in 	<= 1'b0;
    end
    `uvm_info(get_type_name(),$sformatf(rsp.show_state()),UVM_LOW)
  endtask
endclass // Driver extends uvm_driver #(Seq_Item);

class Monitor extends uvm_monitor;   
  `uvm_component_utils(Monitor)
  function new(string name = "Monitor", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  virtual dut_if intf;
  function void build_phase(uvm_phase phase);
    if(! uvm_config_db #(virtual dut_if)::get(null,"uvm_test_top","intf",intf)) 
      begin
        `uvm_error(get_type_name(),$sformatf("Interface not retrieved"))
      end
  endfunction
endclass // Monitor extends uvm_monitor  

class Scoreboard extends uvm_scoreboard;
  `uvm_component_utils(Scoreboard)
  function new(string name = "Scoreboard", uvm_component parent = null);
    super.new(name,parent);
  endfunction
endclass // Scoreboard extends uvm_scoreboard;

class Agent extends uvm_agent;
  `uvm_component_utils(Agent)

  function new(string name = "Agent", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  
  Seqr		  sqr;
  Driver 	  drv;
  Monitor 	mon;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = Seqr::type_id::create("sqr",this);
    drv = Driver::type_id::create("drv",this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
 
endclass // Agent extends uvm_agent;

class Environment extends uvm_env;
  `uvm_component_utils(Environment)
  function new(string name = "Environment", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  
  Agent agent;
  Scoreboard scoreb;
  
  virtual dut_if intf;
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = Agent::type_id::create("agent",this);
    scoreb = Scoreboard::type_id::create("scoreb",this);
  endfunction
endclass // Environment extends uvm_env;

class Test extends uvm_test;
  `uvm_component_utils(Test);
  function new(string name = "Test", uvm_component parent = null);
    super.new(name,parent);
    `uvm_info(get_type_name(),$sformatf("Got here..."),UVM_LOW)
  endfunction
  
  Seq seq;
  Environment environ;

  virtual function void build_phase(uvm_phase phase);
    environ = Environment::type_id::create("environ",this);
    seq 	= Seq::type_id::create("seq",this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    //super.run_phase(phase);
    phase.raise_objection(this);
    seq.start(environ.agent.sqr);
    phase.drop_objection(this);
  endtask
  
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology(); // also displays necessary uvm_info
  endfunction
endclass // Test extends uvm_test;