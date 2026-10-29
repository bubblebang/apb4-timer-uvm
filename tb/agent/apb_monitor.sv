class apb_monitor extends uvm_monitor;

  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;

  uvm_analysis_port #(apb_transaction) item_collected_port;

  protected apb_transaction tr; 
  protected bit recovering_from_reset;

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
    fork
      collect_transfers();
      watch_reset();
    join
  endtask: run_phase

  virtual protected task collect_transfers();
    forever begin
      @(vif.monitor_cb);
      // Discard an incomplete transfer while reset is active or unknown.
      if (vif.monitor_cb.PRESETn !== 1'b1) begin
        tr = null;
        recovering_from_reset = 1'b1;
      end
      else if ((vif.monitor_cb.PSEL    === 1'b1) && 
               (vif.monitor_cb.PENABLE === 1'b0)) begin
        // SETUP phase: capture the request from the actual bus.
        recovering_from_reset = 1'b0;
        tr = apb_transaction::type_id::create("tr");

        tr.addr        = vif.monitor_cb.PADDR;
        tr.write       = vif.monitor_cb.PWRITE;
        tr.wdata       = vif.monitor_cb.PWDATA;
        tr.strb        = vif.monitor_cb.PSTRB;
        tr.prot        = vif.monitor_cb.PPROT;
        tr.rdata       =  '0;
        tr.slverr      = 1'b0;
        tr.wait_cycles = 0;
        tr.aborted     = 1'b0;
      end
      else if ((vif.monitor_cb.PSEL    === 1'b1) && 
               (vif.monitor_cb.PENABLE === 1'b1)) begin
        // ACCESS phase: count wait cycles or capture completion.
        if (tr == null) begin
          if (!recovering_from_reset) begin
            `uvm_error("APB_NO_SETUP", "Observed ACCESS without a captured SETUP")
          end
        end
        else if (vif.monitor_cb.PREADY === 1'b1) begin
          tr.slverr = vif.monitor_cb.PSLVERR;
          if (!tr.write) begin
            tr.rdata = vif.monitor_cb.PRDATA;
          end
          item_collected_port.write(tr);
          tr = null;
        end
        else if (vif.monitor_cb.PREADY === 1'b0) begin
          tr.wait_cycles++;
        end
        else begin
          `uvm_error("APB_READY_X", "PREADY is unknown during ACCESS")
        end
      end
      // Deselection of PSEL before completion is a protocol violation outside reset.
      else if (vif.monitor_cb.PSEL === 1'b0) begin
        if (tr != null) begin
          `uvm_error("APB_DROPPED", "PSEL deasserted before transfer completion")
        end
        tr = null;
      end
    end
  endtask : collect_transfers

  virtual protected task watch_reset();
    forever begin
      wait (vif.PRESETn !== 1'b1);
      tr = null;
      recovering_from_reset = 1'b1;
      wait (vif.PRESETn === 1'b1);
    end
  endtask : watch_reset

endclass : apb_monitor