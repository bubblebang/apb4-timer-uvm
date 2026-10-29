class apb_coverage extends uvm_subscriber #(apb_transaction);

  `uvm_component_utils(apb_coverage)

  covergroup apb_cg with function sample(apb_transaction tr);
    option.per_instance = 1;

    cp_address: coverpoint tr.addr {
      bins ctrl   = {8'h00};
      bins reload = {8'h04};
      bins count  = {8'h08};
      bins status = {8'h0C};

      wildcard bins unaligned = {
        8'b??????01,
        8'b??????10,
        8'b??????11
      };

      bins unmapped_aligned = {[8'h10:8'hFF]} 
        with ((item % 4) == 0);
    }
    
    // Byte strobes apply to writes.
    cp_strobe: coverpoint tr.strb iff (tr.write) {
      bins zero_strobe = {4'b0000};
      bins full_strobe = {4'b1111};
      bins partial_strobe[] = {[4'b0001:4'b1110]};
    }

    cp_direction: coverpoint tr.write {
      bins read_access  = {0};
      bins write_access = {1};
    }

    cp_error: coverpoint tr.slverr {
      bins success        = {0};
      bins error_response = {1};
    }

    cp_wait: coverpoint tr.wait_cycles {
      bins no_wait    = {0};
      bins one_wait   = {1};
      bins two_waits  = {2};
      bins many_waits = {[3:99]};
    }

    cp_privilege: coverpoint tr.prot[0] {
      bins unprivileged = {0};
      bins privileged   = {1};
    }

    cx_address_direction: cross cp_address, cp_direction;
    cx_privilege_direction_error: cross cp_privilege, cp_direction, cp_error {
      ignore_bins unprivileged_write_success = 
        binsof(cp_privilege.unprivileged) &&
        binsof(cp_direction.write_access) &&
        binsof(cp_error.success);
    }
  endgroup : apb_cg

  function new(string name, uvm_component parent);
    super.new(name, parent);
    apb_cg = new();
    apb_cg.set_inst_name({get_full_name(), ".apb_cg"});
  endfunction : new

  virtual function void write(apb_transaction t);
    // Sample only completed transfers with a known error response.
    if (!t.aborted && !$isunknown(t.slverr)) begin
      apb_cg.sample(t);
    end
  endfunction : write

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info(
      "APB_COVERAGE",
      $sformatf(
        {
          "\nAPB coverage:",
          "\n  address                       = %0.2f%%",
          "\n  write strobes                 = %0.2f%%",
          "\n  direction                     = %0.2f%%",
          "\n  error response                = %0.2f%%",
          "\n  wait cycles                   = %0.2f%%",
          "\n  privilege                     = %0.2f%%",
          "\n  address x direction           = %0.2f%%",
          "\n  privilege x direction x error = %0.2f%%",
          "\n  overall                       = %0.2f%%"
        },
        apb_cg.cp_address.get_inst_coverage(),
        apb_cg.cp_strobe.get_inst_coverage(),
        apb_cg.cp_direction.get_inst_coverage(),
        apb_cg.cp_error.get_inst_coverage(),
        apb_cg.cp_wait.get_inst_coverage(),
        apb_cg.cp_privilege.get_inst_coverage(),
        apb_cg.cx_address_direction.get_inst_coverage(),
        apb_cg.cx_privilege_direction_error.get_inst_coverage(),
        apb_cg.get_inst_coverage()
      ),
      UVM_NONE
    )
  endfunction : report_phase

endclass : apb_coverage