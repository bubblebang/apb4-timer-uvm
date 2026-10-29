class apb_ral_policy_seq extends apb_base_seq;

  `uvm_object_utils(apb_ral_policy_seq)

  timer_reg_block reg_model;

  function new(string name = "apb_ral_policy_seq");
    super.new(name);
  endfunction : new

  virtual protected task ral_write(
    uvm_reg        rg,
    uvm_reg_data_t data
  );
    uvm_status_e status;

    rg.write(status, data, UVM_FRONTDOOR, .parent(this));
    
    if (status != UVM_IS_OK) begin
      `uvm_fatal(
        "RAL_WRITE_FAILED",
        $sformatf("Write failed: %s", rg.get_full_name())
      )
    end
  endtask : ral_write

  virtual protected task check_value(
    uvm_reg        rg,
    uvm_reg_data_t expected
  );
    uvm_status_e   status;
    uvm_reg_data_t rdata;

    // Let preceding monitor prediction finish without refreshing
    // the target register's mirror.
    reg_model.ctrl.read(
      status, rdata, UVM_FRONTDOOR, .parent(this)
    );

    if (status != UVM_IS_OK) begin
      `uvm_fatal("RAL_SYNC_READ", "CTRL read failed")
    end

    // Check mirror before a target read can refresh it.
    if (rg.get_mirrored_value() !== expected) begin
      `uvm_fatal(
        "RAL_POLICY_MIRROR",
        $sformatf(
          "%s mirror mismatch: expected = 0x%0h, actual = 0x%0h",
          rg.get_full_name(), expected, rg.get_mirrored_value()
        )
      )
    end

    rg.read(status, rdata, UVM_FRONTDOOR, .parent(this));

    if ((status != UVM_IS_OK) || (rdata !== expected)) begin
      `uvm_fatal(
        "RAL_POLICY_DATA",
        $sformatf(
          "%s read mismatch: expected = 0x%0h, actual = 0x%0h",
          rg.get_full_name(), expected, rdata
        )
      )
    end
  endtask : check_value

  virtual task body();
    logic [31:0]  rdata;
    uvm_status_e  status;
    uvm_reg_data_t status_data;
    bit           expired;

    if (reg_model == null) begin
      `uvm_fatal("NO_REG_MODEL", "RAL sequence requires a register model")
    end

    ral_write(reg_model.ctrl,   32'd0);
    ral_write(reg_model.status, 32'd1);

    // --------------------------------------------------------
    // Rejected writes must preserve hardware and mirror.
    // --------------------------------------------------------
    ral_write(reg_model.reload, 32'h1122_3344);
    check_value(reg_model.reload, 32'h1122_3344);

    // Use a direct APB request because the RAL adapter always
    // generates privileged accesses.
    access_reg(
      8'h04, 1'b1, 32'hFFFF_FFFF,
      rdata, 1'b1, 3'b000
    );

    check_value(reg_model.reload, 32'h1122_3344);

    // --------------------------------------------------------
    // Generate pending status using a one-shot expiry.
    // --------------------------------------------------------
    ral_write(reg_model.reload, 32'd1);
    ral_write(reg_model.ctrl,   32'h0000_0005);

    expired = 1'b0;

    repeat (10) begin
      reg_model.status.read(
        status, status_data, UVM_FRONTDOOR, .parent(this)
      );

      if (status != UVM_IS_OK) begin
        `uvm_fatal("RAL_STATUS_READ", "STATUS polling read failed")
      end

      if (status_data === 32'd1) begin
        expired = 1'b1;
        break;
      end
    end

    if (!expired) begin
      `uvm_fatal("RAL_NO_EXPIRY", "Timer did not set pending status")
    end

    /// Polling updates the STATUS mirror after hardware sets pending.
    check_value(reg_model.status, 32'd1);

    // W1C: writing zero preserves pending.
    ral_write(reg_model.status, 32'd0);
    check_value(reg_model.status, 32'd1);

    // W1C: writing one clears pending.
    ral_write(reg_model.status, 32'd1);
    check_value(reg_model.status, 32'd0);

    // Restore a stopped, masked timer.
    ral_write(reg_model.ctrl, 32'd0);

    `uvm_info(
      "APB_RAL_POLICY",
      "PASS: rejected-write mirror preservation and STATUS W1C prediction",
      UVM_LOW
    )
  endtask : body

endclass : apb_ral_policy_seq