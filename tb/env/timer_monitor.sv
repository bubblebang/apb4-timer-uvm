class timer_monitor extends uvm_monitor;

  `uvm_component_utils(timer_monitor)

  virtual apb_if vif;

  uvm_analysis_port #(timer_observation) item_collected_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", $sformatf("Virtual interface is not set for %s", get_full_name()))
    end

    if (vif == null) begin
      `uvm_fatal("NULL_VIF", $sformatf("Virtual interface is null for %s", get_full_name()))
    end
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    timer_observation obs;

    forever begin
      @(vif.monitor_cb);

      obs = timer_observation::type_id::create("obs");

      // All fields use the same pre-edge clocking-block sample.
      obs.reset_n = vif.monitor_cb.PRESETn;
      obs.sel     = vif.monitor_cb.PSEL;
      obs.enable  = vif.monitor_cb.PENABLE;
      obs.addr    = vif.monitor_cb.PADDR;
      obs.write   = vif.monitor_cb.PWRITE;
      obs.wdata   = vif.monitor_cb.PWDATA;
      obs.strb    = vif.monitor_cb.PSTRB;
      obs.prot    = vif.monitor_cb.PPROT;

      obs.ready   = vif.monitor_cb.PREADY;
      obs.rdata   = vif.monitor_cb.PRDATA;
      obs.slverr  = vif.monitor_cb.PSLVERR;
      obs.irq     = vif.monitor_cb.irq;

      item_collected_port.write(obs);
    end
  endtask : run_phase

endclass : timer_monitor