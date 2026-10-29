class timer_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(timer_scoreboard)

  uvm_analysis_imp #(timer_observation, timer_scoreboard) observation_imp;

  // Reference-model state, meaningful only when model_valid is set.
  protected bit [2:0]  expected_ctrl;
  protected bit [31:0] expected_reload;
  protected bit [31:0] expected_count;
  protected bit        expected_pending;
  protected bit        model_valid;

  localparam bit [7:0] CTRL_ADDR   = 8'h00;
  localparam bit [7:0] RELOAD_ADDR = 8'h04;
  localparam bit [7:0] COUNT_ADDR  = 8'h08;
  localparam bit [7:0] STATUS_ADDR = 8'h0C;

  protected bit access_inflight;

  covergroup timer_cg with function sample(
    bit one_shot_expiry,
    bit periodic_expiry,
    bit masked_pending,
    bit unmasked_pending,
    bit pending_clear,
    bit expiry_clear_collision,
    bit reset_interrupt
  );
    option.per_instance = 1;

    cp_one_shot_expiry: coverpoint one_shot_expiry {
      bins hit = {1};
      ignore_bins inactive = {0};
    }

    cp_periodic_expiry: coverpoint periodic_expiry {
      bins hit = {1};
      ignore_bins inactive = {0};
    }

    cp_masked_pending: coverpoint masked_pending {
      bins hit = {1};
      ignore_bins inactive = {0};
    }

    cp_unmasked_pending: coverpoint unmasked_pending {
      bins hit = {1};
      ignore_bins inactive = {0};
    }

    cp_pending_clear: coverpoint pending_clear {
      bins hit = {1};
      ignore_bins inactive = {0};
    }

    cp_expiry_clear_collision: coverpoint expiry_clear_collision {
      bins hit = {1};
      ignore_bins inactive = {0};
    }

    cp_reset_interrupt: coverpoint reset_interrupt {
      bins hit = {1};
      ignore_bins inactive = {0};
    }

  endgroup : timer_cg

  function new(string name, uvm_component parent);
    super.new(name, parent);
    observation_imp = new("observation_imp", this);

    timer_cg = new();
    timer_cg.set_inst_name({get_full_name(), ".timer_cg"});
  endfunction : new

  virtual protected function void reset_model();
    expected_ctrl    = '0;
    expected_reload  = '0;
    expected_count   = '0;
    expected_pending = 1'b0;
    model_valid      = 1'b1;
  endfunction : reset_model

  virtual protected function bit address_is_mapped(bit [7:0] addr);
    return (addr inside {CTRL_ADDR, RELOAD_ADDR, COUNT_ADDR, STATUS_ADDR});
  endfunction : address_is_mapped

  virtual protected function bit predict_access_error(timer_observation t);
    // Unmapped and unaligned addresses are rejected.
    if (!address_is_mapped(t.addr)) begin
      return 1'b1;
    end 
    if (t.write) begin
      // COUNT is read-only.
      if (t.addr == COUNT_ADDR) begin
        return 1'b1;
      end
        // All writes require privileged access.
      if (!t.prot[0]) begin
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction : predict_access_error

  virtual protected function void check_apb_response(timer_observation t);
    bit          expected_error;
    bit [31:0]   expected_rdata;

    // Responses are checked only at transfer completion.
    if (!((t.sel === 1'b1) && (t.enable === 1'b1) && (t.ready  === 1'b1))) begin
      return;
    end

    // Validate request fields before using two-state predictions.
    if ($isunknown({t.addr, t.write})) begin
      `uvm_error(
        "APB_REQUEST_X",
        "Address or direction is unknown at transfer completion"
      )
      return;
    end

    if ((t.write === 1'b1) && $isunknown(t.prot[0])) begin
      `uvm_error(
        "APB_PROT_X",
        "Privilege is unknown at write completion"
      )
      return;
    end

    expected_error = predict_access_error(t);

    if (t.slverr !== expected_error) begin
      `uvm_error(
        "APB_ERROR_MISMATCH",
        $sformatf(
          "PSLVERR mismatch: addr = 0x%02h, write = %b, expected = %b, actual = %b",
          t.addr, t.write, expected_error, t.slverr
        )
      )
    end

    if (t.write === 1'b0) begin
      // Project policy: rejected reads return zero.
      expected_rdata = '0;

      if (!expected_error) begin
        case (t.addr)
          CTRL_ADDR:   expected_rdata = {29'b0, expected_ctrl};
          RELOAD_ADDR: expected_rdata = expected_reload;
          COUNT_ADDR:  expected_rdata = expected_count;
          STATUS_ADDR: expected_rdata = {31'b0, expected_pending};
          default:     expected_rdata = '0;
        endcase
      end

      if (t.rdata !== expected_rdata) begin
        `uvm_error(
          "APB_READ_MISMATCH",
          $sformatf(
            "Read mismatch: addr = 0x%02h, expected = 0x%08h, actual = 0x%08h",
            t.addr, expected_rdata, t.rdata
          )
        )
        end
    end
  endfunction : check_apb_response

  virtual protected function void check_irq(timer_observation t);
    bit expected_irq;
    expected_irq = expected_pending && expected_ctrl[2];

    if (t.irq !== expected_irq) begin
      `uvm_error(
        "IRQ_MISMATCH",
        $sformatf(
          "IRQ mismatch: expected_irq = %b, actual_irq = %b",
          expected_irq, t.irq
        )
      )
    end
  endfunction : check_irq

  virtual protected function bit model_inputs_known(timer_observation t);
    // Unknown selection means we cannot determine whether a write occurs.
    if ($isunknown(t.sel)) begin
      return 1'b0;
    end
    // No selected transfer: request fields do not affect the model.
    if (t.sel === 1'b0) begin
      return 1'b1;
    end
    if ($isunknown(t.enable)) begin
      return 1'b0;
    end
    // SETUP has no software-write effect; autonomous counting still advances.
    if (t.enable === 1'b0) begin
      return 1'b1;
    end
    if ($isunknown(t.ready)) begin
      return 1'b0;
    end
    // Waiting ACCESS has no software-write effect; counting still advances.
    if (t.ready === 1'b0) begin
      return 1'b1;
    end
    // Completing transfer.
    if ($isunknown({t.addr, t.write})) begin
      return 1'b0;
    end
    // Reads have no software-write effect.
    if (t.write === 1'b0) begin
      return 1'b1;
    end
    if ($isunknown(t.prot[0])) begin
      return 1'b0;
    end
    // Rejected writes have no register-write effects.
    if (predict_access_error(t)) begin
      return 1'b1;
    end

    case (t.addr)
      CTRL_ADDR: begin
        if ($isunknown(t.strb[0])) begin
          return 1'b0;
        end
        if (t.strb[0] && $isunknown(t.wdata[2:0])) begin
          return 1'b0;
        end
      end
      RELOAD_ADDR: begin
        if ($isunknown(t.strb)) begin
          return 1'b0;
        end
        for (int i = 0; i < 4; i++) begin
          if (t.strb[i] && $isunknown(t.wdata[i*8 +: 8])) begin
            return 1'b0;
          end
        end
      end
      STATUS_ADDR: begin
        if ($isunknown(t.strb[0])) begin
          return 1'b0;
        end
        if (t.strb[0] && $isunknown(t.wdata[0])) begin
          return 1'b0;
        end
      end
    endcase

    return 1'b1;
  endfunction : model_inputs_known

  virtual protected function void update_model(timer_observation t);
    bit        write_accepted;
    bit        ctrl_write;
    bit        clear_pending;
    bit        expires;

    bit [2:0]  next_ctrl;
    bit [31:0] next_reload;
    bit [31:0] next_count;
    bit        next_pending;

    // Default: retain the current state.
    next_ctrl    = expected_ctrl;
    next_reload  = expected_reload;
    next_count   = expected_count;
    next_pending = expected_pending;

    // Determine write acceptance from the request and access policy.
    write_accepted = 1'b0;

    if ((t.sel    === 1'b1) &&
        (t.enable === 1'b1) &&
        (t.ready  === 1'b1) &&
        (t.write  === 1'b1)) begin
      write_accepted = !predict_access_error(t);
    end

    ctrl_write = write_accepted &&
                (t.addr == CTRL_ADDR) &&
                t.strb[0];

    clear_pending = write_accepted &&
                    (t.addr == STATUS_ADDR) &&
                    t.strb[0] &&
                    t.wdata[0];

    // Effective CTRL writes suppress counting and expiry.
    expires = !ctrl_write &&
              expected_ctrl[0] &&
              (expected_count == 32'd1);

    // Coverage uses the pre-edge model state and this edge's events.
    timer_cg.sample(
      expires && !expected_ctrl[1],
      expires &&  expected_ctrl[1],
      expected_pending && !expected_ctrl[2],
      expected_pending &&  expected_ctrl[2],
      expected_pending && clear_pending && !expires,
      expires && clear_pending,
      1'b0
    );

    // Predict byte-enabled RELOAD writes.
    if (write_accepted && (t.addr == RELOAD_ADDR)) begin
      for (int i = 0; i < 4; i++) begin
        if (t.strb[i]) begin
          next_reload[i*8 +: 8] = t.wdata[i*8 +: 8];
        end
      end
    end

    // Apply CTRL writes before autonomous countdown updates.
    if (ctrl_write) begin
      next_ctrl = t.wdata[2:0];
      // A rising ENABLE starts a new countdown.
      if (!expected_ctrl[0] && t.wdata[0]) begin
        next_count = expected_reload;
      end
    end
    else if (expected_ctrl[0] && (expected_count != 32'd0)) begin
      if (expires) begin
        if (expected_ctrl[1]) begin
          // Periodic expiry uses the pre-edge RELOAD value.
          next_count = expected_reload;
        end
        else begin
          next_count   = '0;
          next_ctrl[0] = 1'b0;
        end
      end
      else begin
        next_count = expected_count - 32'd1;
      end
    end

    // Expiry takes priority over a simultaneous software clear.
    if (expires) begin
      next_pending = 1'b1;
    end
    else if (clear_pending) begin
      next_pending = 1'b0;
    end

    // Commit the predicted state for the next observation.
    expected_ctrl    = next_ctrl;
    expected_reload  = next_reload;
    expected_count   = next_count;
    expected_pending = next_pending;
  endfunction : update_model

  virtual function void write(timer_observation t);

    // Record reset interruption once, then reset the model.
    if (t.reset_n === 1'b0) begin
      timer_cg.sample(
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
        access_inflight
      );

      access_inflight = 1'b0;
      reset_model();
      return;
    end

    // Unknown reset invalidates the model until a known reset.
    if (t.reset_n !== 1'b1) begin
      access_inflight = 1'b0;
      model_valid = 1'b0;
      return;
    end

    if (!model_valid) begin
      `uvm_error(
        "MODEL_NO_RESET",
        "Timer reference model requires a known reset before checking"
      )
      return;
    end

    // Check pre-edge outputs before applying this edge's updates.
    check_irq(t);
    check_apb_response(t);

    // Do not corrupt the two-state model with unknown inputs.
    if (!model_inputs_known(t)) begin
      `uvm_error(
        "MODEL_INPUT_X",
        "Cannot predict timer state because a relevant input is unknown"
      )

      access_inflight = 1'b0;
      model_valid = 1'b0;
      return;
    end

    // Predict changes caused by this edge, including event coverage.
    update_model(t);

    // Remember SETUP or a waiting ACCESS for reset coverage.
    access_inflight =
      (t.sel === 1'b1) &&
      !((t.enable === 1'b1) && (t.ready === 1'b1));

  endfunction : write

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info(
      "TIMER_COVERAGE",
      $sformatf(
        {
          "\nTimer event coverage:",
          "\n  one-shot expiry        = %0.2f%%",
          "\n  periodic expiry        = %0.2f%%",
          "\n  masked pending         = %0.2f%%",
          "\n  unmasked pending       = %0.2f%%",
          "\n  pending clear          = %0.2f%%",
          "\n  expiry/clear collision = %0.2f%%",
          "\n  reset interruption     = %0.2f%%",
          "\n  overall                = %0.2f%%"
        },
        timer_cg.cp_one_shot_expiry.get_inst_coverage(),
        timer_cg.cp_periodic_expiry.get_inst_coverage(),
        timer_cg.cp_masked_pending.get_inst_coverage(),
        timer_cg.cp_unmasked_pending.get_inst_coverage(),
        timer_cg.cp_pending_clear.get_inst_coverage(),
        timer_cg.cp_expiry_clear_collision.get_inst_coverage(),
        timer_cg.cp_reset_interrupt.get_inst_coverage(),
        timer_cg.get_inst_coverage()
      ),
      UVM_NONE
    )
  endfunction : report_phase

endclass : timer_scoreboard