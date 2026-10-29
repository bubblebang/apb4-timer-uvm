class apb_expiry_clear_seq extends apb_base_seq;

  `uvm_object_utils(apb_expiry_clear_seq)

  function new(string name = "apb_expiry_clear_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    logic [31:0] rdata;

    // Establish a stopped timer with no pending event.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b1, 32'd1, rdata);

    // Periodic countdown of one: expiry every counting clock.
    access_reg(8'h04, 1'b1, 32'd1, rdata);
    access_reg(8'h00, 1'b1, 32'h0000_0007, rdata);

    // Confirm that expiry has set pending.
    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd1) begin
      `uvm_fatal("NO_EXPIRY", "Expected pending status before clear")
    end

    // Each clear completes on an expiry edge.
    // Expiry must win, so pending remains set.
    repeat (2) begin
      access_reg(8'h0C, 1'b1, 32'd1, rdata);

      access_reg(8'h0C, 1'b0, 32'd0, rdata);
      if (rdata !== 32'd1) begin
        `uvm_fatal(
          "EXPIRY_CLEAR_PRIORITY",
          "Simultaneous expiry and clear must leave pending set"
        )
      end
    end

    // Periodic counting must remain enabled.
    access_reg(8'h00, 1'b0, 32'd0, rdata);
    if (rdata !== 32'h0000_0007) begin
      `uvm_fatal("CTRL_CHANGED", "Periodic control settings changed")
    end

    // Stop expiry before attempting an uncontested clear.
    access_reg(8'h00, 1'b1, 32'd0, rdata);

    // Disabling must preserve the pending event.
    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd1) begin
      `uvm_fatal("PENDING_LOST", "Disabling cleared pending status")
    end

    // With no new expiry, software clear must succeed.
    access_reg(8'h0C, 1'b1, 32'd1, rdata);

    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("CLEAR_FAILED", "STATUS did not clear after stopping")
    end

    `uvm_info(
      "APB_EXPIRY_CLEAR",
      "PASS: expiry wins over simultaneous STATUS clear",
      UVM_LOW
    )
  endtask : body

endclass : apb_expiry_clear_seq