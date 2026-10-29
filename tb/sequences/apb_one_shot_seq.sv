class apb_one_shot_seq extends apb_base_seq;

  `uvm_object_utils(apb_one_shot_seq)

  function new(string name = "apb_one_shot_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    logic [31:0] rdata;
    bit expired;

    // Stop the timer and clear pending status.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b1, 32'd1, rdata);

    // Program a five-clock countdown.
    access_reg(8'h04, 1'b1, 32'd5, rdata);

    // CTRL: IRQ enabled, periodic disabled, timer enabled.
    access_reg(8'h00, 1'b1, 32'h0000_0005, rdata);

    // Bound polling so a missing expiry cannot hang the test.
    expired = 1'b0;

    repeat (10) begin
      access_reg(8'h0C, 1'b0, 32'd0, rdata);

      if (rdata === 32'd1) begin
        expired = 1'b1;
        break;
      end
    end

    if (!expired) begin
      `uvm_fatal("NO_EXPIRY", "Timer did not set STATUS pending")
    end

    // One-shot expiry stops COUNT and clears ENABLE.
    access_reg(8'h08, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("COUNT_NOT_ZERO", "COUNT is not zero after expiry")
    end

    access_reg(8'h00, 1'b0, 32'd0, rdata);
    if (rdata !== 32'h0000_0004) begin
      `uvm_fatal(
        "CTRL_MISMATCH",
        "Expected ENABLE cleared and IRQ enable retained"
      )
    end

    // Writing zero must preserve the pending event.
    access_reg(8'h0C, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd1) begin
      `uvm_fatal("W0_CHANGED_STATUS", "STATUS write-zero cleared pending")
    end

    // Writing one clears the pending event.
    access_reg(8'h0C, 1'b1, 32'd1, rdata);
    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("W1C_FAILED", "STATUS write-one did not clear pending")
    end

    `uvm_info(
      "APB_ONE_SHOT",
      "PASS: one-shot expiry, stopped state, and STATUS W1C",
      UVM_LOW
    )
  endtask : body

endclass : apb_one_shot_seq