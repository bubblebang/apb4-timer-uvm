class timer_count_reg extends uvm_reg;

  `uvm_object_utils(timer_count_reg)

  uvm_reg_field count_value;

  function new(string name = "timer_count_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction : new

  virtual function void build();
    count_value = uvm_reg_field::type_id::create("count_value");

    count_value.configure(
      .parent(this),
      .size(32),
      .lsb_pos(0),
      .access("RO"),
      .volatile(1),
      .reset(0),
      .has_reset(1),
      .is_rand(0),
      .individually_accessible(1)
    );

    // Autonomous countdown is checked by the timer scoreboard.
    count_value.set_compare(UVM_NO_CHECK);
  endfunction : build

endclass : timer_count_reg