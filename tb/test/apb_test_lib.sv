class apb_base_test extends uvm_test;

  `uvm_component_utils(apb_base_test)

  apb_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction : build_phase

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction : end_of_elaboration_phase

endclass : apb_base_test

class apb_smoke_test extends apb_base_test;

  `uvm_component_utils(apb_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_smoke_seq seq;
    seq = apb_smoke_seq::type_id::create("seq");

    phase.raise_objection(this, get_type_name());
    seq.start(env.agent.sequencer);
    phase.drop_objection(this, get_type_name());
  endtask : run_phase

endclass : apb_smoke_test

class apb_one_shot_test extends apb_base_test;

  `uvm_component_utils(apb_one_shot_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_one_shot_seq seq;
    seq = apb_one_shot_seq::type_id::create("seq");

    phase.raise_objection(this, get_type_name());
    seq.start(env.agent.sequencer);
    phase.drop_objection(this, get_type_name());
  endtask : run_phase

endclass : apb_one_shot_test

class apb_periodic_test extends apb_base_test;

  `uvm_component_utils(apb_periodic_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_periodic_seq seq;
    seq = apb_periodic_seq::type_id::create("seq");

    phase.raise_objection(this, get_type_name());
    seq.start(env.agent.sequencer);
    phase.drop_objection(this, get_type_name());
  endtask : run_phase

endclass : apb_periodic_test

class apb_error_test extends apb_base_test;

  `uvm_component_utils(apb_error_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_error_seq seq;
    seq = apb_error_seq::type_id::create("seq");

    phase.raise_objection(this, get_type_name());
    seq.start(env.agent.sequencer);
    phase.drop_objection(this, get_type_name());
  endtask : run_phase

endclass : apb_error_test

class apb_strobe_test extends apb_base_test;

  `uvm_component_utils(apb_strobe_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_strobe_seq seq;
    seq = apb_strobe_seq::type_id::create("seq");

    phase.raise_objection(this, get_type_name());
    seq.start(env.agent.sequencer);
    phase.drop_objection(this, get_type_name());
  endtask : run_phase

endclass : apb_strobe_test

class apb_irq_mask_test extends apb_base_test;

  `uvm_component_utils(apb_irq_mask_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_irq_mask_seq seq;
    seq = apb_irq_mask_seq::type_id::create("seq");

    phase.raise_objection(this, get_type_name());
    seq.start(env.agent.sequencer);
    phase.drop_objection(this, get_type_name());
  endtask : run_phase

endclass : apb_irq_mask_test

class apb_boundary_test extends apb_base_test;

  `uvm_component_utils(apb_boundary_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_boundary_seq seq;
    seq = apb_boundary_seq::type_id::create("seq");

    phase.raise_objection(this, get_type_name());
    seq.start(env.agent.sequencer);
    phase.drop_objection(this, get_type_name());
  endtask : run_phase

endclass : apb_boundary_test

class apb_restart_test extends apb_base_test;

  `uvm_component_utils(apb_restart_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_restart_seq seq;
    seq = apb_restart_seq::type_id::create("seq");

    phase.raise_objection(this, get_type_name());
    seq.start(env.agent.sequencer);
    phase.drop_objection(this, get_type_name());
  endtask : run_phase

endclass : apb_restart_test

class apb_reload_update_test extends apb_base_test;

  `uvm_component_utils(apb_reload_update_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_reload_update_seq seq;
    seq = apb_reload_update_seq::type_id::create("seq");

    phase.raise_objection(this, get_type_name());
    seq.start(env.agent.sequencer);
    phase.drop_objection(this, get_type_name());
  endtask : run_phase

endclass : apb_reload_update_test

class apb_expiry_clear_test extends apb_base_test;

  `uvm_component_utils(apb_expiry_clear_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_expiry_clear_seq seq;
    seq = apb_expiry_clear_seq::type_id::create("seq");

    phase.raise_objection(this, get_type_name());
    seq.start(env.agent.sequencer);
    phase.drop_objection(this, get_type_name());
  endtask : run_phase

endclass : apb_expiry_clear_test

class apb_reset_test extends apb_base_test;

  `uvm_component_utils(apb_reset_test)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Retrieve the same interface configured for the driver.
    if (!uvm_config_db#(virtual apb_if)::get(this, "env.agent.driver", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "Reset test could not obtain the interface")
    end

    if (vif == null) begin
      `uvm_fatal("NULL_VIF", "Reset test interface is null")
    end
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    apb_reset_seq seq;

    seq = apb_reset_seq::type_id::create("seq");

    phase.raise_objection(this, get_type_name());

    fork
      seq.start(env.agent.sequencer);

      begin
        // Detect the target ACCESS before its first sampling edge.
        // This tests abort/recovery, not cancellation of a pending wait assertion.
        wait (
          (vif.PRESETn === 1'b1) &&
          (vif.PSEL    === 1'b1) &&
          (vif.PENABLE === 1'b1) &&
          (vif.PWRITE  === 1'b1) &&
          (vif.PADDR   === 8'h04) &&
          (vif.PWDATA  === 32'd200)
        );

        // tb_top asserts reset at the next falling clock edge.
        -> vif.reset_request;
        @(vif.reset_done);
      end
    join

    phase.drop_objection(this, get_type_name());
  endtask : run_phase

endclass : apb_reset_test

class apb_random_test extends apb_base_test;

  `uvm_component_utils(apb_random_test)

  int unsigned num_iters = 1;
  int unsigned num_xfers = 300;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_random_seq seq;

    void'($value$plusargs("NUM_ITERS=%d", num_iters));
    void'($value$plusargs("NUM_XFERS=%d", num_xfers));

    phase.raise_objection(this, get_type_name());

    for (int unsigned i = 0; i < num_iters; i++) begin
      `uvm_info(
        "ITER",
        $sformatf("Iteration %0d of %0d (%0d transfers)", i + 1, num_iters, num_xfers),
        UVM_LOW
      )

      seq = apb_random_seq::type_id::create($sformatf("seq_%0d", i));
      seq.num_transfers = num_xfers;
      seq.start(env.agent.sequencer);
    end

    phase.drop_objection(this, get_type_name());
  endtask : run_phase

endclass : apb_random_test

class apb_ral_smoke_test extends apb_base_test;

  `uvm_component_utils(apb_ral_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_ral_smoke_seq seq;

    seq = apb_ral_smoke_seq::type_id::create("seq");

    // Use the same register model as the monitor-driven predictor.
    seq.reg_model = env.reg_model;

    phase.raise_objection(this);
    seq.start(env.agent.sequencer);
    phase.drop_objection(this);
  endtask : run_phase

endclass : apb_ral_smoke_test

class apb_ral_update_test extends apb_base_test;

  `uvm_component_utils(apb_ral_update_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_ral_update_seq seq;

    seq = apb_ral_update_seq::type_id::create("seq");
    seq.reg_model = env.reg_model;

    phase.raise_objection(this);
    seq.start(null);
    phase.drop_objection(this);
  endtask : run_phase

endclass : apb_ral_update_test

class apb_ral_reset_test extends apb_base_test;

  `uvm_component_utils(apb_ral_reset_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_ral_smoke_seq seq;
    uvm_reg          regs[$];
    uvm_status_e     status;
    uvm_reg_data_t   rdata;

    phase.raise_objection(this);

    // Establish nonzero hardware and mirrored RELOAD values.
    seq = apb_ral_smoke_seq::type_id::create("seq");
    seq.reg_model = env.reg_model;
    seq.start(null);

    if (env.reg_model.reload.get_mirrored_value() !== 32'h1122_3344) begin
      `uvm_fatal(
        "RAL_RESET_PRECONDITION",
        "Expected a nonzero RELOAD mirror before reset"
      )
    end

    // Request an actual DUT reset from tb_top.
    -> env.vif.reset_request;
    @(env.vif.reset_done);

    // Collect all registers in the model.
    env.reg_model.get_registers(regs);

    // Check reset prediction before readback can refresh the mirrors.
    foreach (regs[i]) begin
      if (regs[i].get_mirrored_value() !== 32'd0) begin
        `uvm_fatal(
          "RAL_RESET_MIRROR",
          $sformatf(
            "%s mirror did not reset: actual = 0x%0h",
            regs[i].get_full_name(),
            regs[i].get_mirrored_value()
          )
        )
      end

      if (regs[i].get() !== 32'd0) begin
        `uvm_fatal(
          "RAL_RESET_DESIRED",
          $sformatf(
            "%s desired value did not reset",
            regs[i].get_full_name()
          )
        )
      end
    end

    // Independently check the actual hardware reset values.
    foreach (regs[i]) begin
      regs[i].read(status, rdata, UVM_FRONTDOOR);

      if (status != UVM_IS_OK) begin
        `uvm_fatal(
          "RAL_RESET_READ",
          $sformatf("Reset read failed: %s", regs[i].get_full_name())
        )
      end

      if (rdata !== 32'd0) begin
        `uvm_fatal(
          "RAL_RESET_DATA",
          $sformatf(
            "%s hardware reset mismatch: expected = 0, actual = 0x%0h",
            regs[i].get_full_name(), rdata
          )
        )
      end
    end

    `uvm_info(
      "APB_RAL_RESET",
      "PASS: hardware reset values and RAL model reset synchronization",
      UVM_LOW
    )

    phase.drop_objection(this);
  endtask : run_phase

endclass : apb_ral_reset_test

class apb_ral_strobe_test extends apb_base_test;

  `uvm_component_utils(apb_ral_strobe_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_ral_strobe_seq seq;

    seq = apb_ral_strobe_seq::type_id::create("seq");
    seq.reg_model = env.reg_model;

    phase.raise_objection(this);

    // This sequence directly sends APB items as well as RAL accesses.
    seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask : run_phase

endclass : apb_ral_strobe_test

class apb_ral_policy_test extends apb_base_test;

  `uvm_component_utils(apb_ral_policy_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_ral_policy_seq seq;

    seq = apb_ral_policy_seq::type_id::create("seq");
    seq.reg_model = env.reg_model;

    phase.raise_objection(this);
    seq.start(env.agent.sequencer);
    phase.drop_objection(this);
  endtask : run_phase

endclass : apb_ral_policy_test
