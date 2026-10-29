class apb_restart_seq extends apb_base_seq;

  `uvm_object_utils(apb_restart_seq)

  function new(string name = "apb_restart_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    logic [31:0] rdata;
    logic [31:0] held_count;

    // Establish a stopped timer with no pending event.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b1, 32'd1, rdata);

    // Start a 100-clock one-shot countdown with IRQ masked.
    access_reg(8'h04, 1'b1, 32'd100, rdata);
    access_reg(8'h00, 1'b1, 32'd1, rdata);

    // Confirm that the countdown is running.
    access_reg(8'h08, 1'b0, 32'd0, rdata);
    if ($isunknown(rdata) ||
        (rdata == 32'd0) ||
        (rdata >= 32'd100)) begin
      `uvm_fatal(
        "COUNT_NOT_RUNNING",
        $sformatf("Expected COUNT between 1 and 99, actual = %0d", rdata)
      )
    end

    // --------------------------------------------------------
    // Disabling holds the current count.
    // --------------------------------------------------------
    access_reg(8'h00, 1'b1, 32'd0, rdata);

    // Capture after disable completes; COUNT has stopped changing.
    access_reg(8'h08, 1'b0, 32'd0, held_count);

    if ($isunknown(held_count) ||
        (held_count == 32'd0) ||
        (held_count >= 32'd100)) begin
      `uvm_fatal(
        "DISABLED_COUNT",
        "Expected a nonzero remaining count after disabling"
      )
    end

    repeat (3) begin
      access_reg(8'h08, 1'b0, 32'd0, rdata);

      if (rdata !== held_count) begin
        `uvm_fatal(
          "COUNT_NOT_HELD",
          $sformatf(
            "Disabled COUNT changed: expected = %0d, actual = %0d",
            held_count, rdata
          )
        )
      end
    end

    `uvm_info(
      "APB_RESTART",
      "PASS: disabling preserves COUNT",
      UVM_LOW
    )

    // --------------------------------------------------------
    // RELOAD writes do not change a disabled COUNT.
    // --------------------------------------------------------
    access_reg(8'h04, 1'b1, 32'd200, rdata);

    access_reg(8'h08, 1'b0, 32'd0, rdata);
    if (rdata !== held_count) begin
      `uvm_fatal(
        "RELOAD_CHANGED_COUNT",
        "Writing RELOAD changed the disabled COUNT"
      )
    end

    // --------------------------------------------------------
    // Re-enable loads the new RELOAD instead of resuming COUNT.
    // --------------------------------------------------------
    access_reg(8'h00, 1'b1, 32'd1, rdata);

    access_reg(8'h08, 1'b0, 32'd0, rdata);

    // Some clocks pass before this read completes.
    // A fresh 200-clock countdown must still be above 100.
    if ($isunknown(rdata)  ||
        (rdata <= 32'd100) ||
        (rdata >= 32'd200)) begin
      `uvm_fatal(
        "RESTART_FAILED",
        $sformatf(
          "Expected a fresh countdown between 101 and 199, actual = %0d",
          rdata
        )
      )
    end

    `uvm_info(
      "APB_RESTART",
      "PASS: re-enable loads the updated RELOAD",
      UVM_LOW
    )

    // Stop the timer and confirm no expiry occurred.
    access_reg(8'h00, 1'b1, 32'd0, rdata);

    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("UNEXPECTED_EXPIRY", "Timer expired unexpectedly")
    end
  endtask : body

endclass : apb_restart_seq