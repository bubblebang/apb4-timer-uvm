class apb_env extends uvm_env;

  `uvm_component_utils(apb_env)

  apb_agent        agent;
  apb_coverage     coverage;
  timer_monitor    timer_mon;
  timer_scoreboard scoreboard;

  timer_reg_block   reg_model;
  apb_reg_adapter   reg_adapter;
  apb_reg_predictor reg_predictor;

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual apb_if)::get(this, "timer_mon", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "Environment could not obtain the reset interface")
    end

    if (vif == null) begin
      `uvm_fatal("NULL_VIF", "Environment reset interface is null")
    end

    agent = apb_agent::type_id::create("agent", this);
    coverage = apb_coverage::type_id::create("coverage", this);
    timer_mon = timer_monitor::type_id::create("timer_mon", this);
    scoreboard = timer_scoreboard::type_id::create("scoreboard", this);

    // Build and lock the register hierarchy before connecting the predictor.
    reg_model = timer_reg_block::type_id::create("reg_model");
    reg_model.configure(null, "");
    reg_model.build();
    reg_model.lock_model();

    // Initialize model values; this does not reset the DUT.
    reg_model.reset();

    reg_adapter = apb_reg_adapter::type_id::create("reg_adapter");

    reg_predictor = apb_reg_predictor::type_id::create("reg_predictor", this);
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    agent.monitor.item_collected_port.connect(
      coverage.analysis_export
    );

    timer_mon.item_collected_port.connect(
      scoreboard.observation_imp
    );

    // RAL-generated accesses use the existing APB sequencer.
    if (agent.get_is_active() == UVM_ACTIVE) begin
      reg_model.default_map.set_sequencer(
        agent.sequencer,
        reg_adapter
      );
    end

    // Mirror updates come from the bus monitor.
    reg_model.default_map.set_auto_predict(0);

    reg_predictor.map     = reg_model.default_map;
    reg_predictor.adapter = reg_adapter;

    agent.monitor.item_collected_port.connect(
      reg_predictor.bus_in
    );
  endfunction : connect_phase

  virtual task run_phase(uvm_phase phase);
    forever begin
      // Handles reset already active at startup and later assertions.
      wait (vif.PRESETn === 1'b0);

      // Reset desired and mirrored values to their configured defaults.
      reg_model.reset("HARD");

      // Wait for release before watching for another reset.
      wait (vif.PRESETn === 1'b1);
    end
  endtask : run_phase

endclass : apb_env