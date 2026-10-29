class timer_reload_reg extends uvm_reg;

  `uvm_object_utils(timer_reload_reg)

  rand uvm_reg_field reload_byte[4];

  function new(string name = "timer_reload_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction : new

  virtual function void build();
    // Separate byte fields let UVM 1.2 prediction honor each PSTRB bit.
    foreach (reload_byte[i]) begin
      reload_byte[i] = uvm_reg_field::type_id::create(
        $sformatf("reload_byte%0d", i)
      );

      reload_byte[i].configure(
        .parent(this),
        .size(8),
        .lsb_pos(i * 8),
        .access("RW"),
        .volatile(0),
        .reset(0),
        .has_reset(1),
        .is_rand(1),
        .individually_accessible(1)
      );
    end
  endfunction : build

endclass : timer_reload_reg