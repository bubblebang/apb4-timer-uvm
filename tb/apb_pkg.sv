package apb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // APB agent and coverage
  `include "apb_transaction.sv"
  `include "apb_sequencer.sv"
  `include "apb_driver.sv"
  `include "apb_monitor.sv"
  `include "apb_agent.sv"
  `include "apb_coverage.sv"

  // Timer observation and functional checking
  `include "timer_observation.sv"
  `include "timer_monitor.sv"
  `include "timer_scoreboard.sv"

  // Register model: register classes, register block, adapter, predictor
  `include "timer_ctrl_reg.sv"
  `include "timer_reload_reg.sv"
  `include "timer_count_reg.sv"
  `include "timer_status_reg.sv"
  `include "timer_reg_block.sv"
  `include "apb_reg_adapter.sv"
  `include "apb_reg_predictor.sv"

  // Environment
  `include "apb_env.sv"

  // Sequences: base class before derived classes
  `include "apb_base_seq.sv"
  `include "apb_smoke_seq.sv"
  `include "apb_one_shot_seq.sv"
  `include "apb_periodic_seq.sv"
  `include "apb_error_seq.sv"
  `include "apb_strobe_seq.sv"
  `include "apb_irq_mask_seq.sv"
  `include "apb_boundary_seq.sv"
  `include "apb_restart_seq.sv"
  `include "apb_reload_update_seq.sv"
  `include "apb_expiry_clear_seq.sv"
  `include "apb_reset_seq.sv"
  `include "apb_random_seq.sv"
  `include "apb_ral_smoke_seq.sv"
  `include "apb_ral_update_seq.sv"
  `include "apb_ral_strobe_seq.sv"
  `include "apb_ral_policy_seq.sv"

  // Tests depend on the environment and sequences
  `include "apb_test_lib.sv"

endpackage : apb_pkg