class apb_reload_update_seq extends apb_base_seq;

  `uvm_object_utils(apb_reload_update_seq)

  function new(string name = "apb_reload_update_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    logic [31:0] rdata;
    bit          expired;

    // Establish a stopped timer with no pending event.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b1, 32'd1, rdata);

    // Start periodic counting with IRQ enabled.
    access_reg(8'h04, 1'b1, 32'd100, rdata);
    access_reg(8'h00, 1'b1, 32'h0000_0007, rdata);

    // Update RELOAD while the current countdown is running.
    access_reg(8'h04, 1'b1, 32'd200, rdata);

    // The write changes RELOAD, not the current COUNT.
    access_reg(8'h08, 1'b0, 32'd0, rdata);

    if ($isunknown(rdata) ||
        (rdata == 32'd0) ||
        (rdata >= 32'd100)) begin
      `uvm_fatal(
        "CURRENT_COUNT_CHANGED",
        $sformatf(
          "Expected original countdown between 1 and 99, actual = %0d",
          rdata
        )
      )
    end

    // Confirm that the new reload value was stored.
    access_reg(8'h04, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd200) begin
      `uvm_fatal("RELOAD_MISMATCH", "RELOAD did not update to 200")
    end

    `uvm_info(
      "APB_RELOAD_UPDATE",
      "PASS: RELOAD write preserves the running countdown",
      UVM_LOW
    )

    // Wait for the original countdown to expire.
    expired = 1'b0;

    repeat (40) begin
      access_reg(8'h0C, 1'b0, 32'd0, rdata);

      if (rdata === 32'd1) begin
        expired = 1'b1;
        break;
      end
    end

    if (!expired) begin
      `uvm_fatal("NO_EXPIRY", "Original countdown did not expire")
    end

    // Periodic expiry must load the updated RELOAD value.
    // A few counting clocks pass before this read completes.
    access_reg(8'h08, 1'b0, 32'd0, rdata);

    if ($isunknown(rdata) ||
        (rdata <= 32'd100) ||
        (rdata >= 32'd200)) begin
      `uvm_fatal(
        "UPDATED_RELOAD_NOT_USED",
        $sformatf(
          "Expected reloaded countdown between 101 and 199, actual = %0d",
          rdata
        )
      )
    end

    // Periodic expiry must retain the control settings.
    access_reg(8'h00, 1'b0, 32'd0, rdata);
    if (rdata !== 32'h0000_0007) begin
      `uvm_fatal(
        "CTRL_MISMATCH",
        "Periodic expiry changed the control settings"
      )
    end

    // Stop before clearing STATUS so no new expiry can interfere.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b1, 32'd1, rdata);

    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("STATUS_NOT_CLEAR", "Pending status did not clear")
    end

    `uvm_info(
      "APB_RELOAD_UPDATE",
      "PASS: periodic expiry uses the updated RELOAD",
      UVM_LOW
    )
  endtask : body

endclass : apb_reload_update_seq