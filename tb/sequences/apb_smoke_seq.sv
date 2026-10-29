class apb_smoke_seq extends uvm_sequence #(apb_transaction);

  `uvm_object_utils(apb_smoke_seq)

  function new(string name = "apb_smoke_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    apb_transaction tr;

    // Write 10 to RELOAD.
    tr = apb_transaction::type_id::create("write_tr");
    
    start_item(tr);
    tr.addr  = 8'h04;
    tr.write = 1'b1;
    tr.wdata = 32'd10;
    tr.strb  = 4'b1111;
    tr.prot  = 3'b001;
    finish_item(tr);

    if (tr.aborted) begin
      `uvm_fatal("APB_ABORT", "RELOAD write was aborted by reset")
    end

    if (tr.slverr !== 1'b0) begin
      `uvm_fatal("APB_WRITE_ERR", "RELOAD write returned an error")
    end

    // Verify RELOAD readback.
    tr = apb_transaction::type_id::create("read_tr");

    start_item(tr);
    tr.addr  = 8'h04;
    tr.write = 1'b0;
    tr.wdata = '0;
    tr.strb  = 4'b0000;
    tr.prot  = 3'b001;
    finish_item(tr);

    if (tr.aborted) begin
      `uvm_fatal("APB_ABORT", "RELOAD read was aborted by reset")
    end

    if (tr.slverr !== 1'b0) begin
      `uvm_fatal("APB_READ_ERR", "RELOAD read returned an error")
    end

    if (tr.rdata !== 32'd10) begin
      `uvm_fatal(
        "APB_MISMATCH",
        $sformatf(
          "RELOAD mismatch: expected = 10, actual = 0x%08h",
          tr.rdata
        )
      )
    end

    `uvm_info("APB_SMOKE", "PASS: RELOAD write and read", UVM_LOW)
  endtask : body

endclass : apb_smoke_seq