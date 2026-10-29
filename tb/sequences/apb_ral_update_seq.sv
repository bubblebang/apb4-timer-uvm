class apb_ral_update_seq extends uvm_sequence #(apb_transaction);

  `uvm_object_utils(apb_ral_update_seq)

  timer_reg_block reg_model;

  function new(string name = "apb_ral_update_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    uvm_status_e   status;
    uvm_reg_data_t rdata;

    if (reg_model == null) begin
      `uvm_fatal("NO_REG_MODEL", "RAL sequence requires a register model")
    end

    // Stop the timer.
    reg_model.ctrl.write(
      status, 32'd0, UVM_FRONTDOOR, .parent(this)
    );
    if (status != UVM_IS_OK) begin
      `uvm_fatal("RAL_CTRL_WRITE", "CTRL write failed")
    end

    // Establish a known hardware and mirrored value.
    reg_model.reload.write(
      status, 32'd10, UVM_FRONTDOOR, .parent(this)
    );
    if (status != UVM_IS_OK) begin
      `uvm_fatal("RAL_WRITE", "Initial RELOAD write failed")
    end

    // Complete a subsequent access before inspecting the mirror.
    reg_model.reload.read(
      status, rdata, UVM_FRONTDOOR, .parent(this)
    );
    if ((status != UVM_IS_OK) || (rdata !== 32'd10)) begin
      `uvm_fatal(
        "RAL_INITIAL_VALUE", 
        $sformatf(
          "Initial RELOAD read mismatched: expected=0x0000000a, actual=0x%0h, status=%s", 
          rdata, status.name()
        )
      )
    end

    // --------------------------------------------------------
    // set(): change only the model's desired value.
    // --------------------------------------------------------
    reg_model.reload.set(32'd25);

    if (reg_model.reload.get() !== 32'd25) begin
      `uvm_fatal("RAL_DESIRED", "Desired value did not become 25")
    end

    if (reg_model.reload.get_mirrored_value() !== 32'd10) begin
      `uvm_fatal("RAL_MIRROR", "set() unexpectedly changed the mirror")
    end

    if (!reg_model.reload.needs_update()) begin
      `uvm_fatal("RAL_NEEDS_UPDATE", "Expected a pending register update")
    end

    // Do not read RELOAD here: read prediction can replace the
    // desired value with the observed hardware value.

    // --------------------------------------------------------
    // update(): write the desired value through APB.
    // --------------------------------------------------------
    reg_model.reload.update(
      status, UVM_FRONTDOOR, .parent(this)
    );
    if (status != UVM_IS_OK) begin
      `uvm_fatal("RAL_UPDATE", "RELOAD update failed")
    end

    // A different register access allows the monitor to finish
    // predicting the RELOAD write before mirror comparison.
    reg_model.ctrl.read(
      status, rdata, UVM_FRONTDOOR, .parent(this)
    );
    if ((status != UVM_IS_OK) || (rdata !== 32'd0)) begin
      `uvm_fatal("RAL_CTRL_READ", "Stopped CTRL read mismatched")
    end

    if (reg_model.reload.get_mirrored_value() !== 32'd25) begin
      `uvm_fatal("RAL_UPDATE_MIRROR", "RELOAD mirror did not become 25")
    end

    if (reg_model.reload.needs_update()) begin
      `uvm_fatal("RAL_STILL_PENDING", "RELOAD still needs an update")
    end

    // --------------------------------------------------------
    // mirror(UVM_CHECK): read DUT and compare against the mirror.
    // --------------------------------------------------------
    reg_model.reload.mirror(
      status, UVM_CHECK, UVM_FRONTDOOR, .parent(this)
    );
    if (status != UVM_IS_OK) begin
      `uvm_fatal("RAL_MIRROR_ACCESS", "RELOAD mirror read failed")
    end

    // Mirror comparison failures are reported by UVM itself.
    `uvm_info(
      "APB_RAL_UPDATE",
      "Completed desired-value, update, and mirror-check test",
      UVM_LOW
    )
  endtask : body

endclass : apb_ral_update_seq