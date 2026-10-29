class apb_ral_strobe_seq extends apb_base_seq;

  `uvm_object_utils(apb_ral_strobe_seq)

  timer_reg_block reg_model;

  function new(string name = "apb_ral_strobe_seq");
    super.new(name);
  endfunction : new

  virtual protected task check_reload(
    input bit [31:0] expected
  );
    uvm_status_e   status;
    uvm_reg_data_t rdata;

    // Allow the preceding write's monitor prediction to finish.
    // Reading CTRL does not refresh the RELOAD mirror.
    reg_model.ctrl.read(
      status, rdata, UVM_FRONTDOOR, .parent(this)
    );

    if ((status != UVM_IS_OK) || (rdata !== 32'd0)) begin
      `uvm_fatal("RAL_CTRL_READ", "Expected a stopped timer")
    end

    // Check write prediction before reading the hardware register.
    if (reg_model.reload.get_mirrored_value() !== expected) begin
      `uvm_fatal(
        "RAL_STROBE_MIRROR",
        $sformatf(
          "RELOAD mirror mismatch: expected = 0x%08h, actual = 0x%0h",
          expected, reg_model.reload.get_mirrored_value()
        )
      )
    end

    // Independently verify the actual hardware value.
    reg_model.reload.read(
      status, rdata, UVM_FRONTDOOR, .parent(this)
    );

    if ((status != UVM_IS_OK) || (rdata !== expected)) begin
      `uvm_fatal(
        "RAL_STROBE_DATA",
        $sformatf(
          "RELOAD read mismatch: expected = 0x%08h, actual = 0x%0h",
          expected, rdata
        )
      )
    end
  endtask : check_reload

  virtual task body();
    uvm_status_e status;
    logic [31:0] rdata;

    if (reg_model == null) begin
      `uvm_fatal("NO_REG_MODEL", "RAL sequence requires a register model")
    end

    access_reg(8'h00, 1'b1, 32'd0, rdata);

    // Establish the baseline through RAL.
    reg_model.reload.write(
      status, 32'h1122_3344, UVM_FRONTDOOR, .parent(this)
    );

    if (status != UVM_IS_OK) begin
      `uvm_fatal("RAL_RELOAD_WRITE", "Baseline RELOAD write failed")
    end

    check_reload(32'h1122_3344);

    // Update bytes 2 and 0.
    access_reg(
      8'h04, 1'b1, 32'hAABB_CCDD,
      rdata, 1'b0, 3'b001, 4'b0101
    );

    check_reload(32'h11BB_33DD);

    // Update the complementary bytes: 3 and 1.
    access_reg(
      8'h04, 1'b1, 32'h5566_7788,
      rdata, 1'b0, 3'b001, 4'b1010
    );

    check_reload(32'h55BB_77DD);

    // Zero strobes must preserve both hardware and mirror.
    access_reg(
      8'h04, 1'b1, 32'hFFFF_FFFF,
      rdata, 1'b0, 3'b001, 4'b0000
    );

    check_reload(32'h55BB_77DD);

    `uvm_info(
      "APB_RAL_STROBE",
      "PASS: partial and zero-strobe writes preserve correct RAL mirrors",
      UVM_LOW
    )
  endtask : body

endclass : apb_ral_strobe_seq