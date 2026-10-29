class apb_driver extends uvm_driver #(apb_transaction);

  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
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

  virtual protected task drive_idle();
    vif.driver_cb.PSEL    <= 1'b0;
    vif.driver_cb.PENABLE <= 1'b0;
    vif.driver_cb.PADDR   <= 8'h00;
    vif.driver_cb.PWRITE  <= 1'b0;
    vif.driver_cb.PWDATA  <= 32'h0000_0000;
    vif.driver_cb.PSTRB   <= 4'b0000;
    vif.driver_cb.PPROT   <= 3'b001;
  endtask : drive_idle

  virtual protected task drive_transfer(apb_transaction tr);
    // SETUP: present the request
    @(vif.driver_cb);
    vif.driver_cb.PSEL    <= 1'b1;
    vif.driver_cb.PENABLE <= 1'b0;
    vif.driver_cb.PADDR   <= tr.addr;
    vif.driver_cb.PWRITE  <= tr.write;
    vif.driver_cb.PWDATA  <= tr.wdata;
    vif.driver_cb.PSTRB   <= tr.write ? tr.strb : 4'b0000;
    vif.driver_cb.PPROT   <= tr.prot;

    // ACCESS: keep the request stable and assert PENABLE
    @(vif.driver_cb);
    vif.driver_cb.PENABLE <= 1'b1;

    forever begin
      @(vif.driver_cb);
      if (vif.driver_cb.PREADY === 1'b1) begin
        // Capture the response at the completing edge
        tr.slverr = vif.driver_cb.PSLVERR;
        if (!tr.write) begin
          tr.rdata = vif.driver_cb.PRDATA;
        end
        break;
      end
      tr.wait_cycles++;
      
      /*
      // TEMPORARY: deliberately corrupt write data during a wait state to verify "p_wait_stable" assertion
      if ((tr.wait_cycles == 1) && tr.write) begin
        vif.driver_cb.PWDATA <= tr.wdata ^ 32'd1;
      end
      */

      // Bound the wait so a broken DUT cannot hang simulation.
      if (tr.wait_cycles >= 100) begin
        `uvm_fatal("APB_TIMEOUT", $sformatf("Transfer timed out: addr = 0x%02h", tr.addr))
      end
    end
    // Completion was sampled; release the bus after this edge.
    drive_idle();
  endtask : drive_transfer

  virtual task run_phase(uvm_phase phase);
    // Initialize request signals at the first clocking event.
    @(vif.driver_cb);
    drive_idle();

    fork
      get_and_drive();
      reset_signals();
    join
  endtask : run_phase

  virtual protected task get_and_drive();
    forever begin
      // Wait until released reset has been sampled.
      do begin
        @(vif.driver_cb);
      end while (vif.driver_cb.PRESETn !== 1'b1);

      seq_item_port.get_next_item(req);

      // Clear response metadata before reusing the item.
      req.rdata       = '0;
      req.slverr      = 1'b0;
      req.wait_cycles = 0;
      req.aborted     = 1'b0;
      
      // Reset may have returned while waiting for an item.
      if (vif.PRESETn !== 1'b1) begin
        req.aborted = 1'b1;
      end
      else begin
        fork : TRANSFER_OR_RESET
          drive_transfer(req);

          // Watch the actual reset signal for asynchronous assertion.
          begin 
            wait (vif.PRESETn !== 1'b1);
            req.aborted = 1'b1;
          end
        join_any

        // Stop whichever branch is still running.
        disable TRANSFER_OR_RESET;
      end

      // Handle both reset-before-transfer and reset-during-transfer.
      if (req.aborted) begin
        `uvm_warning(
          "RESET_ABORT", 
          $sformatf("APB transfer interrupted by reset: addr = 0x%02h", req.addr)
        )
        // Clear the interrupted request, including for a short reset pulse.
        @(vif.driver_cb);
        drive_idle();
      end

      // Exactly one item_done() for each get_next_item().
      seq_item_port.item_done();
    end
  endtask : get_and_drive

  virtual protected task reset_signals();
    forever begin
      @(vif.driver_cb);
      // Keep request signals idle while reset is active or unknown.
      if (vif.driver_cb.PRESETn !== 1'b1) begin
        drive_idle();
      end
    end
  endtask : reset_signals


endclass : apb_driver