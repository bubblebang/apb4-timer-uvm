class apb_base_seq extends uvm_sequence #(apb_transaction);

  `uvm_object_utils(apb_base_seq)

  function new(string name = "apb_base_seq");
    super.new(name);
  endfunction : new

  // Perform an APB access and check the expected error response.
  virtual protected task access_reg(
    input  bit [7:0]    addr,
    input  bit          is_write,
    input  bit [31:0]   data,
    output logic [31:0] rdata,
    input  bit          expected_slverr = 1'b0,
    input  bit [2:0]    prot = 3'b001,
    input  bit [3:0]    strb = 4'b1111
  );
    apb_transaction tr;

    tr = apb_transaction::type_id::create("tr");

    start_item(tr);
    tr.addr  = addr;
    tr.write = is_write;
    tr.wdata = data;
    tr.strb  = is_write ? strb : 4'b0000;
    tr.prot  = prot;
    finish_item(tr);

    if (tr.aborted) begin
      `uvm_fatal(
        "APB_ABORT",
        $sformatf("Access aborted by reset: addr = 0x%02h", addr)
      )
    end

    if (tr.slverr !== expected_slverr) begin
      `uvm_fatal(
        "APB_ACCESS_ERR",
        $sformatf(
          "Unexpected PSLVERR: addr = 0x%02h, expected = %b, actual = %b",
          addr, expected_slverr, tr.slverr
        )
      )
    end

    rdata = tr.rdata;
  endtask : access_reg

endclass : apb_base_seq