class apb_boundary_seq extends apb_base_seq;

  `uvm_object_utils(apb_boundary_seq)

  function new(string name = "apb_boundary_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    logic [31:0] rdata;
    bit          expired;

    // Establish a stopped timer with no pending event.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b1, 32'd1, rdata);

    // --------------------------------------------------------
    // RELOAD = 0: enabled timer remains at zero without expiry.
    // --------------------------------------------------------
    access_reg(8'h04, 1'b1, 32'd0, rdata);

    // Enable one-shot mode and IRQ.
    access_reg(8'h00, 1'b1, 32'h0000_0005, rdata);

    // Repeated accesses allow several counting clocks to pass.
    repeat (3) begin
      access_reg(8'h08, 1'b0, 32'd0, rdata);
      if (rdata !== 32'd0) begin
        `uvm_fatal(
          "ZERO_RELOAD_COUNT",
          "COUNT must remain zero when started with RELOAD = 0"
        )
      end

      access_reg(8'h0C, 1'b0, 32'd0, rdata);
      if (rdata !== 32'd0) begin
        `uvm_fatal(
          "ZERO_RELOAD_STATUS",
          "RELOAD = 0 must not generate an expiry"
        )
      end
    end

    access_reg(8'h00, 1'b0, 32'd0, rdata);
    if (rdata !== 32'h0000_0005) begin
      `uvm_fatal(
        "ZERO_RELOAD_CTRL",
        "ENABLE must remain set when RELOAD = 0"
      )
    end

    `uvm_info(
      "APB_BOUNDARY",
      "PASS: zero reload remains enabled without expiry",
      UVM_LOW
    )

    // --------------------------------------------------------
    // RELOAD = 1: smallest nonzero one-shot countdown.
    // --------------------------------------------------------

    // Disable first so the next enable produces a 0-to-1 transition.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h04, 1'b1, 32'd1, rdata);
    access_reg(8'h00, 1'b1, 32'h0000_0005, rdata);

    expired = 1'b0;

    repeat (10) begin
      access_reg(8'h0C, 1'b0, 32'd0, rdata);

      if (rdata === 32'd1) begin
        expired = 1'b1;
        break;
      end
    end

    if (!expired) begin
      `uvm_fatal(
        "ONE_RELOAD_NO_EXPIRY",
        "Timer did not expire with RELOAD = 1"
      )
    end

    access_reg(8'h08, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("ONE_RELOAD_COUNT", "COUNT must be zero after expiry")
    end

    access_reg(8'h00, 1'b0, 32'd0, rdata);
    if (rdata !== 32'h0000_0004) begin
      `uvm_fatal(
        "ONE_RELOAD_CTRL",
        "One-shot expiry must clear ENABLE and retain IRQ enable"
      )
    end

    // Restore a stopped timer with no pending interrupt.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b1, 32'd1, rdata);

    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("BOUNDARY_CLEANUP", "STATUS did not clear")
    end

    `uvm_info(
      "APB_BOUNDARY",
      "PASS: one-clock reload expires and stops",
      UVM_LOW
    )
  endtask : body

endclass : apb_boundary_seq