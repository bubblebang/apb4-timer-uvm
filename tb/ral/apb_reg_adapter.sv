class apb_reg_adapter extends uvm_reg_adapter;

  `uvm_object_utils(apb_reg_adapter)

  function new(string name = "apb_reg_adapter");
    super.new(name);

    supports_byte_enable = 1;
    provides_responses   = 0;
  endfunction : new

  // Convert a RAL access into an APB request.
  virtual function uvm_sequence_item reg2bus(
    const ref uvm_reg_bus_op rw
  );
    apb_transaction tr;

    tr = apb_transaction::type_id::create("tr");

    // Reject addresses that would be truncated by the 8-bit APB bus.
    if (rw.addr > 'hFF) begin
      `uvm_fatal(
        "RAL_ADDR",
        $sformatf("RAL address exceeds APB address width: 0x%0h", rw.addr)
      )
    end

    tr.addr  = rw.addr[7:0];
    tr.write = (rw.kind == UVM_WRITE);
    tr.wdata = rw.data[31:0];
    tr.strb  = tr.write ? rw.byte_en[3:0] : 4'b0000;

    // This project's writes require privileged access.
    tr.prot = 3'b001;

    return tr;
  endfunction : reg2bus

  // Convert a completed APB transaction into a RAL result.
  virtual function void bus2reg(
    uvm_sequence_item bus_item,
    ref uvm_reg_bus_op rw
  );
    apb_transaction tr;

    if (!$cast(tr, bus_item)) begin
      `uvm_fatal(
        "RAL_CAST",
        "APB register adapter received an incompatible transaction"
      )
      return;
    end

    rw.kind    = tr.write ? UVM_WRITE : UVM_READ;
    rw.addr    = tr.addr;
    rw.data    = tr.write ? tr.wdata : tr.rdata;
    rw.byte_en = tr.write ? tr.strb : 4'b1111;

    if (tr.aborted || (tr.slverr !== 1'b0)) begin
      rw.status = UVM_NOT_OK;
    end
    else if (!tr.write && $isunknown(tr.rdata)) begin
      rw.status = UVM_HAS_X;
    end
    else begin
      rw.status = UVM_IS_OK;
    end
  endfunction : bus2reg

endclass : apb_reg_adapter