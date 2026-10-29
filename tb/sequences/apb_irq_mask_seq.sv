class apb_irq_mask_seq extends apb_base_seq;

  `uvm_object_utils(apb_irq_mask_seq)

  function new(string name = "apb_irq_mask_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    logic [31:0] rdata;
    bit expired;

    // Stop and mask the timer.
    access_reg(8'h00, 1'b1, 32'd0, rdata);

    // Clear pending status.
    access_reg(8'h0C, 1'b1, 32'd1, rdata);

    access_reg(8'h04, 1'b1, 32'd5, rdata);

    // Enable one-shot mode with IRQ masked.
    access_reg(8'h00, 1'b1, 32'd1, rdata);

    expired = 1'b0;
    repeat (10) begin
      access_reg(8'h0C, 1'b0, 32'd0, rdata);

      if (rdata === 32'd1) begin
        expired = 1'b1;
        break;
      end
    end

    if (!expired) begin
      `uvm_fatal("NO_EXPIRY", "Masked timer did not set pending status")
    end

    // Expiry stops the timer; IRQ remains masked.
    access_reg(8'h00, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("CTRL_MISMATCH", "Expected stopped, masked one-shot timer")
    end

    // Unmask the existing pending event without restarting the timer.
    // The scoreboard should now observe IRQ high.
    access_reg(8'h00, 1'b1, 32'd4, rdata);

    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd1) begin
      `uvm_fatal("PENDING_LOST", "Unmasking IRQ changed pending status")
    end

    // Mask again: IRQ must fall, but pending must remain set.
    access_reg(8'h00, 1'b1, 32'd0, rdata);

    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd1) begin
      `uvm_fatal("PENDING_LOST", "Masking IRQ cleared pending status")
    end

    // Unmask again for the STATUS strobe checks.
    access_reg(8'h00, 1'b1, 32'd4, rdata);

    // Upper-byte strobes must not clear STATUS bit 0.
    access_reg(
      8'h0C, 1'b1, 32'd1,
      rdata, 1'b0, 3'b001, 4'b1110
    );

    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd1) begin
      `uvm_fatal("STATUS_STROBE", "Upper-byte write cleared pending")
    end

    // Zero strobes must also preserve pending.
    access_reg(
      8'h0C, 1'b1, 32'd1,
      rdata, 1'b0, 3'b001, 4'b0000
    );

    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd1) begin
      `uvm_fatal("STATUS_STROBE", "Zero-strobe write cleared pending")
    end

    // Selecting byte 0 and writing one must clear pending and IRQ.
    access_reg(
      8'h0C, 1'b1, 32'd1,
      rdata, 1'b0, 3'b001, 4'b0001
    );

    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("W1C_FAILED", "Byte-zero write did not clear pending")
    end

    // Leave the timer stopped and masked.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h00, 1'b0, 32'd0, rdata);

    if (rdata !== 32'd0) begin
      `uvm_fatal("CLEANUP_FAILED", "CTRL did not return to zero")
    end

    `uvm_info(
      "APB_IRQ_MASK",
      "PASS: IRQ masking, pending retention, and STATUS strobe gating",
      UVM_LOW
    )
  endtask : body

endclass : apb_irq_mask_seq