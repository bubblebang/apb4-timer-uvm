class apb_ral_smoke_seq extends uvm_sequence #(apb_transaction);

  `uvm_object_utils(apb_ral_smoke_seq)

  timer_reg_block reg_model;

  function new(string name = "apb_ral_smoke_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    uvm_status_e   status;
    uvm_reg_data_t rdata;

    if (reg_model == null) begin
      `uvm_fatal("NO_REG_MODEL", "RAL sequence requires a register model")
    end

    // Keep the timer stopped.
    reg_model.ctrl.write(
      status, 32'd0, UVM_FRONTDOOR, .parent(this)
    );

    if (status != UVM_IS_OK) begin
      `uvm_fatal("RAL_CTRL_WRITE", "RAL CTRL write failed")
    end

    // Write through RAL -> adapter -> sequencer -> driver.
    reg_model.reload.write(
      status, 32'h1122_3344, UVM_FRONTDOOR, .parent(this)
    );

    if (status != UVM_IS_OK) begin
      `uvm_fatal("RAL_RELOAD_WRITE", "RAL RELOAD write failed")
    end

    // Read through the same frontdoor path.
    reg_model.reload.read(
      status, rdata, UVM_FRONTDOOR, .parent(this)
    );

    if (status != UVM_IS_OK) begin
      `uvm_fatal("RAL_RELOAD_READ", "RAL RELOAD read failed")
    end

    if (rdata !== 32'h1122_3344) begin
      `uvm_fatal(
        "RAL_READ_MISMATCH",
        $sformatf(
          "RELOAD expected = 0x11223344, actual = 0x%0h",
          rdata
        )
      )
    end

    // Check the mirror after frontdoor readback. The strobe and policy
    // sequences separately check write prediction before target readback.
    if (reg_model.reload.get_mirrored_value() !== 32'h1122_3344) begin
      `uvm_fatal(
        "RAL_MIRROR_MISMATCH",
        $sformatf(
          "RELOAD mirror expected = 0x11223344, actual = 0x%0h",
          reg_model.reload.get_mirrored_value()
        )
      )
    end

    `uvm_info(
      "APB_RAL_SMOKE",
      "PASS: RAL RELOAD write/read and mirror prediction",
      UVM_LOW
    )
  endtask : body

endclass : apb_ral_smoke_seq