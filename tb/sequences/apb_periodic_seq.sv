class apb_periodic_seq extends apb_base_seq;

  `uvm_object_utils(apb_periodic_seq)

  function new(string name = "apb_periodic_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    logic [31:0] rdata;
    bit expired;

    // Stop the timer and remove any previous pending event.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b1, 32'd1, rdata);

    // Allow enough time between expiries for APB checks.
    access_reg(8'h04, 1'b1, 32'd40, rdata);

    // CTRL: IRQ enabled, periodic mode, timer enabled.
    access_reg(8'h00, 1'b1, 32'h0000_0007, rdata);

    // Observe and acknowledge three successive expiry events.
    repeat (3) begin
      expired = 1'b0;

      repeat (30) begin
        access_reg(8'h0C, 1'b0, 32'd0, rdata);

        if (rdata === 32'd1) begin
          expired = 1'b1;
          break;
        end
      end

      if (!expired) begin
        `uvm_fatal("NO_EXPIRY", "Periodic timer did not set STATUS pending")
      end

      // Periodic expiry must leave ENABLE asserted.
      access_reg(8'h00, 1'b0, 32'd0, rdata);
      if (rdata !== 32'h0000_0007) begin
        `uvm_fatal(
          "CTRL_MISMATCH",
          "Periodic expiry did not preserve CTRL"
        )
      end

      // COUNT must remain within the running countdown range.
      access_reg(8'h08, 1'b0, 32'd0, rdata);
      if ($isunknown(rdata) ||
          (rdata < 32'd1)   || 
          (rdata > 32'd40)) begin
        `uvm_fatal(
          "COUNT_RANGE",
          $sformatf("Periodic COUNT outside 1-40: actual = 0x%08h", rdata)
        )
      end

      // Clear pending without stopping the timer.
      access_reg(8'h0C, 1'b1, 32'd1, rdata);
      access_reg(8'h0C, 1'b0, 32'd0, rdata);
      if (rdata !== 32'd0) begin
        `uvm_fatal("W1C_FAILED", "Periodic STATUS did not clear")
      end
    end

    // Stop the timer, then clear any remaining pending event.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b1, 32'd1, rdata);

    access_reg(8'h00, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("STOP_FAILED", "CTRL did not clear when stopping timer")
    end

    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("STATUS_NOT_CLEAR", "STATUS remained pending after cleanup")
    end

    `uvm_info(
      "APB_PERIODIC",
      "PASS: repeated periodic expiry, ENABLE retention, and STATUS clear",
      UVM_LOW
    )
  endtask : body

endclass : apb_periodic_seq