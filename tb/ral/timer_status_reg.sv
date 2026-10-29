class timer_status_reg extends uvm_reg;

  `uvm_object_utils(timer_status_reg)

  uvm_reg_field pending;

  function new(string name = "timer_status_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction : new

  virtual function void build();
    pending = uvm_reg_field::type_id::create("pending");

    pending.configure(
      .parent(this),
      .size(1),
      .lsb_pos(0),
      .access("W1C"),
      .volatile(1),
      .reset(0),
      .has_reset(1),
      .is_rand(0),
      .individually_accessible(1)
    );

    // Hardware sets pending on expiry.
    // Exact status behavior is checked by the timer scoreboard.
    pending.set_compare(UVM_NO_CHECK);
  endfunction : build

endclass : timer_status_reg