class apb_reg_predictor extends uvm_reg_predictor #(apb_transaction);

  `uvm_component_utils(apb_reg_predictor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual function void write(apb_transaction tr);

    // Failed or interrupted accesses must not update mirrors.
    if (tr.aborted || (tr.slverr !== 1'b0)) begin
      return;
    end

    // Only these addresses belong to this register model.
    if (!(tr.addr inside {8'h00, 8'h04, 8'h08, 8'h0C})) begin
      return;
    end

    super.write(tr);
  endfunction : write

endclass : apb_reg_predictor