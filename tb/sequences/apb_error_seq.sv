class apb_error_seq extends apb_base_seq;

  `uvm_object_utils(apb_error_seq)

  function new(string name = "apb_error_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    logic [31:0] rdata;

    // Disable the timer and establish a recognizable RELOAD value.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h04, 1'b1, 32'h1122_3344, rdata);

    // Unprivileged write: reject it and preserve RELOAD.
    access_reg(8'h04, 1'b1, 32'hFFFF_FFFF, rdata, 1'b1, 3'b000);

    access_reg(8'h04, 1'b0, 32'd0, rdata);
    if (rdata !== 32'h1122_3344) begin
      `uvm_fatal("RELOAD_CHANGED", "Rejected write modified RELOAD")
    end

    // Unprivileged reads are allowed.
    access_reg(8'h04, 1'b0, 32'd0, rdata, 1'b0, 3'b000);

    if (rdata !== 32'h1122_3344) begin
      `uvm_fatal("READ_MISMATCH", "Unprivileged RELOAD read mismatched")
    end

    // COUNT is read-only. Compare its value before and after rejection.
    access_reg(8'h08, 1'b0, 32'd0, rdata);
    begin
      logic [31:0] count_before;
      count_before = rdata;

      access_reg(8'h08, 1'b1, 32'd99, rdata, 1'b1);
      access_reg(8'h08, 1'b0, 32'd0, rdata);

      if (rdata !== count_before) begin
        `uvm_fatal("COUNT_CHANGED", "Rejected write modified COUNT")
      end
    end

    // Aligned but unmapped read: error and zero data by project policy.
    access_reg(8'h10, 1'b0, 32'd0, rdata, 1'b1);
    if (rdata !== 32'd0) begin
      `uvm_fatal("ERROR_READ_DATA", "Rejected read did not return zero")
    end

    // Unaligned write must not alias the RELOAD register.
    access_reg(8'h05, 1'b1, 32'hAABB_CCDD, rdata, 1'b1);

    access_reg(8'h04, 1'b0, 32'd0, rdata);
    if (rdata !== 32'h1122_3344) begin
      `uvm_fatal("RELOAD_CHANGED", "Unaligned write modified RELOAD")
    end

    `uvm_info(
      "APB_ERROR_TEST",
      "PASS: privilege restrictions, COUNT protection, and invalid addresses",
      UVM_LOW
    )
  endtask : body

endclass : apb_error_seq