`timescale 1ns/1ps
`include "apb_if.sv"
`include "apb_pkg.sv"

`ifndef APB_WAIT_CYCLES
  `define APB_WAIT_CYCLES 0
`endif

module tb_top;

  import uvm_pkg::*;
  import apb_pkg::*;

  parameter int unsigned WAIT_CYCLES = `APB_WAIT_CYCLES;

  logic PCLK    = 1'b0;
  logic PRESETn = 1'b0;

  // 10 ns clock period
  always #5ns PCLK = ~PCLK;

  apb_if apb (
    .PCLK    (PCLK),
    .PRESETn (PRESETn)
  );

  apb_timer #(
    .WAIT_CYCLES (WAIT_CYCLES)
  ) dut (
    .PCLK    (PCLK),
    .PRESETn (PRESETn),

    .PADDR   (apb.PADDR),
    .PSEL    (apb.PSEL),
    .PENABLE (apb.PENABLE),
    .PWRITE  (apb.PWRITE),
    .PWDATA  (apb.PWDATA),
    .PSTRB   (apb.PSTRB),
    .PPROT   (apb.PPROT),

    .PRDATA  (apb.PRDATA),
    .PREADY  (apb.PREADY),
    .PSLVERR (apb.PSLVERR),
    .irq     (apb.irq)
  );
  
  // Generate reset
  initial begin
    // Initial power-on reset.
    repeat (4) @(negedge PCLK);
    PRESETn = 1'b1;

    // Subsequent resets requested by UVM tests.
    forever begin
      @(apb.reset_request);

      // Assert away from the DUT's active clock edge.
      @(negedge PCLK);
      PRESETn = 1'b0;

      // Hold reset across three rising clock edges.
      repeat (3) @(negedge PCLK);
      PRESETn = 1'b1;

      -> apb.reset_done;
    end
  end

  initial begin
    // Give the agent's driver and monitor access to the interface.
    uvm_config_db#(virtual apb_if)::set(
      null,
      "uvm_test_top.env.agent.*",
      "vif",
      apb
    );

    uvm_config_db#(virtual apb_if)::set(
      null,
      "uvm_test_top.env.timer_mon",
      "vif",
      apb
    );

    run_test();
  end

endmodule : tb_top