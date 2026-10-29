class apb_agent extends uvm_agent;

  `uvm_component_utils_begin(apb_agent)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
  `uvm_component_utils_end
  
  apb_sequencer sequencer;
  apb_driver    driver;
  apb_monitor   monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is present in both active and passive agents.
    monitor = apb_monitor::type_id::create("monitor", this);

    // Only an active agent generates bus traffic.
    if (get_is_active() == UVM_ACTIVE) begin
      sequencer = apb_sequencer::type_id::create("sequencer", this);
      driver = apb_driver::type_id::create("driver", this);    
    end
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction : connect_phase

endclass : apb_agent