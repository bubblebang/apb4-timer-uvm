class timer_reg_block extends uvm_reg_block;

  `uvm_object_utils(timer_reg_block)

  rand timer_ctrl_reg   ctrl;
  rand timer_reload_reg reload;
       timer_count_reg  count;
       timer_status_reg status;

  function new(string name = "timer_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction : new

  virtual function void build();

    ctrl = timer_ctrl_reg::type_id::create("ctrl");
    ctrl.configure(this);
    ctrl.build();

    reload = timer_reload_reg::type_id::create("reload");
    reload.configure(this);
    reload.build();

    count = timer_count_reg::type_id::create("count");
    count.configure(this);
    count.build();

    status = timer_status_reg::type_id::create("status");
    status.configure(this);
    status.build();

    // Base address 0, four-byte bus, little endian, byte addressing.
    default_map = create_map(
      "default_map",
      'h0,
      4,
      UVM_LITTLE_ENDIAN,
      1
    );

    default_map.add_reg(ctrl,   'h00, "RW");
    default_map.add_reg(reload, 'h04, "RW");
    default_map.add_reg(count,  'h08, "RO");
    default_map.add_reg(status, 'h0C, "RW");

  endfunction : build

endclass : timer_reg_block