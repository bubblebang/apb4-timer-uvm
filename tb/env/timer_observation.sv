 class timer_observation extends uvm_sequence_item;

  // Preserve unknown values observed on the interface.
  logic        reset_n;
  logic        sel;
  logic        enable;
  logic [7:0]  addr;
  logic        write;
  logic [31:0] wdata;
  logic [3:0]  strb;
  logic [2:0]  prot;

  logic        ready;
  logic [31:0] rdata;
  logic        slverr;
  logic        irq;

  `uvm_object_utils_begin(timer_observation)
    `uvm_field_int(reset_n, UVM_DEFAULT | UVM_BIN)
    `uvm_field_int(sel,     UVM_DEFAULT | UVM_BIN)
    `uvm_field_int(enable,  UVM_DEFAULT | UVM_BIN)
    `uvm_field_int(addr,    UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(write,   UVM_DEFAULT | UVM_BIN)
    `uvm_field_int(wdata,   UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(strb,    UVM_DEFAULT | UVM_BIN)
    `uvm_field_int(prot,    UVM_DEFAULT | UVM_BIN)
    `uvm_field_int(ready,   UVM_DEFAULT | UVM_BIN)
    `uvm_field_int(rdata,   UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(slverr,  UVM_DEFAULT | UVM_BIN)
    `uvm_field_int(irq,     UVM_DEFAULT | UVM_BIN)
  `uvm_object_utils_end

  function new(string name = "timer_observation");
    super.new(name);
  endfunction : new

endclass : timer_observation