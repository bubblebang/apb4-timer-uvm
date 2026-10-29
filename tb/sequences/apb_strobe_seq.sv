class apb_strobe_seq extends apb_base_seq;

  `uvm_object_utils(apb_strobe_seq)

  function new(string name = "apb_strobe_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    logic [31:0] rdata;
    bit [31:0] expected;
    bit [3:0]  mask;

    // Keep the timer stopped.
    access_reg(8'h00, 1'b1, 32'd0, rdata);

    // Test every RELOAD byte-enable combination independently.
    for (int m = 0; m < 16; m++) begin
      mask = m;

      access_reg(8'h04, 1'b1, 32'h1122_3344, rdata);

      access_reg(
        8'h04, 1'b1, 32'hAABB_CCDD,
        rdata, 1'b0, 3'b001, mask
      );

      // Each selected byte comes from the new write data.
      expected = 32'h1122_3344;

      if (mask[0]) expected[7:0]   = 8'hDD;
      if (mask[1]) expected[15:8]  = 8'hCC;
      if (mask[2]) expected[23:16] = 8'hBB;
      if (mask[3]) expected[31:24] = 8'hAA;

      access_reg(8'h04, 1'b0, 32'd0, rdata);

      if (rdata !== expected) begin
        `uvm_fatal(
          "STROBE_MISMATCH",
          $sformatf(
            "RELOAD strobe = %04b, expected = 0x%08h, actual = 0x%08h",
            mask, expected, rdata
          )
        )
      end
    end

    // CTRL fields reside in byte 0.
    // Selecting only upper bytes must not enable the timer.
    access_reg(
      8'h00, 1'b1, 32'h0000_0007,
      rdata, 1'b0, 3'b001, 4'b1110
    );

    access_reg(8'h00, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("CTRL_STROBE", "Upper-byte write modified CTRL")
    end

    // Selecting byte 0 updates CTRL. Keep ENABLE clear.
    access_reg(
      8'h00, 1'b1, 32'h0000_0004,
      rdata, 1'b0, 3'b001, 4'b0001
    );

    access_reg(8'h00, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd4) begin
      `uvm_fatal("CTRL_STROBE", "Byte-zero write did not update CTRL")
    end

    // Zero strobes must preserve the existing CTRL value.
    access_reg(
      8'h00, 1'b1, 32'd0,
      rdata, 1'b0, 3'b001, 4'b0000
    );

    access_reg(8'h00, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd4) begin
      `uvm_fatal("CTRL_STROBE", "Zero-strobe write modified CTRL")
    end

    // Restore a stopped, masked timer.
    access_reg(8'h00, 1'b1, 32'd0, rdata);

    `uvm_info(
      "APB_STROBE",
      "PASS: all RELOAD strobes and CTRL byte-zero gating",
      UVM_LOW
    )
  endtask : body

endclass : apb_strobe_seq
