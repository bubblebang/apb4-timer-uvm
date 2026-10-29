class apb_reset_seq extends apb_base_seq;

  `uvm_object_utils(apb_reset_seq)

  function new(string name = "apb_reset_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    apb_transaction tr;
    logic [31:0]    rdata;

    // Establish nonzero timer state before reset.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b1, 32'd1, rdata);
    access_reg(8'h04, 1'b1, 32'd1000, rdata);
    access_reg(8'h00, 1'b1, 32'h0000_0007, rdata);

    // The test will interrupt this particular write with reset.
    // Do not use access_reg(): it treats an abort as fatal.
    tr = apb_transaction::type_id::create("interrupted_write");

    start_item(tr);
    tr.addr  = 8'h04;
    tr.write = 1'b1;
    tr.wdata = 32'd200;
    tr.strb  = 4'b1111;
    tr.prot  = 3'b001;
    finish_item(tr);

    if (!tr.aborted) begin
      `uvm_fatal(
        "RESET_NOT_ABORTED",
        "Expected the RELOAD write to be aborted by reset"
      )
    end

    // Response fields are not checked for an aborted transfer.
    `uvm_info(
      "APB_RESET",
      "PASS: active transfer aborted by reset",
      UVM_LOW
    )

    // The driver waits for released reset before driving these.
    access_reg(8'h00, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("RESET_CTRL", "CTRL did not reset to zero")
    end

    access_reg(8'h04, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("RESET_RELOAD", "RELOAD did not reset to zero")
    end

    access_reg(8'h08, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("RESET_COUNT", "COUNT did not reset to zero")
    end

    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("RESET_STATUS", "STATUS did not reset to zero")
    end

    // Confirm successful writes and reads after reset.
    access_reg(8'h04, 1'b1, 32'h1122_3344, rdata);
    access_reg(8'h04, 1'b0, 32'd0, rdata);

    if (rdata !== 32'h1122_3344) begin
      `uvm_fatal(
        "RESET_RECOVERY",
        "RELOAD write/read failed after reset"
      )
    end

    `uvm_info(
      "APB_RESET",
      "PASS: reset values and post-reset transfers",
      UVM_LOW
    )
  endtask : body

endclass : apb_reset_seq