class timer_ctrl_reg extends uvm_reg;

  `uvm_object_utils(timer_ctrl_reg)

  rand uvm_reg_field enable;
  rand uvm_reg_field periodic;
  rand uvm_reg_field irq_enable;

  function new(string name = "timer_ctrl_reg");
    // Register name, register width, register-model coverage.
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction : new

  virtual function void build();

    enable = uvm_reg_field::type_id::create("enable");
    enable.configure(
      .parent                 (this),
      .size                   (1),
      .lsb_pos                (0),
      .access                 ("RW"),
      .volatile               (1),
      .reset                  (0),
      .has_reset              (1),
      .is_rand                (1),
      .individually_accessible (0)
    );

    periodic = uvm_reg_field::type_id::create("periodic");
    periodic.configure(
      .parent                 (this),
      .size                   (1),
      .lsb_pos                (1),
      .access                 ("RW"),
      .volatile               (0),
      .reset                  (0),
      .has_reset              (1),
      .is_rand                (1),
      .individually_accessible (0)
    );

    irq_enable = uvm_reg_field::type_id::create("irq_enable");
    irq_enable.configure(
      .parent                 (this),
      .size                   (1),
      .lsb_pos                (2),
      .access                 ("RW"),
      .volatile               (0),
      .reset                  (0),
      .has_reset              (1),
      .is_rand                (1),
      .individually_accessible (0)
    );

    // Hardware clears ENABLE on one-shot expiry.
    // The bus predictor alone cannot track that autonomous change.
    enable.set_compare(UVM_NO_CHECK);

  endfunction : build

endclass : timer_ctrl_reg