`timescale 1ns/1ps
`include "apb_if.sv"

// Standalone directed testbench; excluded from the UVM file list.

module tb_top;

  parameter int unsigned WAIT_CYCLES = 0;

  logic PCLK    = 1'b0;
  logic PRESETn = 1'b0;

  logic        slverr;
  logic [31:0] rdata;

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

  task automatic apb_write(
    input  logic [7:0]  addr,
    input  logic [31:0] data,
    input  logic [3:0]  strb,
    input  logic [2:0]  prot,
    output logic        slverr
    );
    int unsigned wait_cycles = 0;

    // SETUP: select the peripheral and present the request.
    @(apb.driver_cb);
    apb.driver_cb.PSEL    <= 1'b1;
    apb.driver_cb.PENABLE <= 1'b0;
    apb.driver_cb.PADDR   <= addr;
    apb.driver_cb.PWRITE  <= 1'b1;
    apb.driver_cb.PWDATA  <= data;
    apb.driver_cb.PSTRB   <= strb;
    apb.driver_cb.PPROT   <= prot;

    // ACCESS: keep the request unchanged and assert PENABLE.
    @(apb.driver_cb);
    apb.driver_cb.PENABLE <= 1'b1;

    // Sample each ACCESS edge until the transfer completes.
    forever begin
      @(apb.driver_cb);

      if (apb.driver_cb.PREADY === 1'b1) begin
        slverr = apb.driver_cb.PSLVERR;
        break;
      end

      wait_cycles++;

      // Fail transfers that exceed the timeout.
      if (wait_cycles > WAIT_CYCLES + 10) begin
        $fatal(1, "APB write timeout: addr = 0x%02h", addr);
      end
    end

    // Transfer completed: return the bus to IDLE.
    apb.driver_cb.PSEL    <= 1'b0;
    apb.driver_cb.PENABLE <= 1'b0;
    apb.driver_cb.PWRITE  <= 1'b0;
    apb.driver_cb.PSTRB   <= 4'b0;
  endtask : apb_write
  
  task automatic apb_read(
    input  logic [7:0]  addr,
    input  logic [2:0]  prot,
    output logic [31:0] data,
    output logic        slverr
  );
    int unsigned wait_cycles = 0;

    // SETUP: present the read request.
    @(apb.driver_cb);
    apb.driver_cb.PSEL    <= 1'b1;
    apb.driver_cb.PENABLE <= 1'b0;
    apb.driver_cb.PADDR   <= addr;
    apb.driver_cb.PWRITE  <= 1'b0;
    apb.driver_cb.PSTRB   <= 4'b0;
    apb.driver_cb.PPROT   <= prot;

    // ACCESS
    @(apb.driver_cb);
    apb.driver_cb.PENABLE <= 1'b1;

    forever begin
      @(apb.driver_cb);

      if (apb.driver_cb.PREADY === 1'b1) begin
        // Capture the response sampled at the completion edge.
        data   = apb.driver_cb.PRDATA;
        slverr = apb.driver_cb.PSLVERR;
        break;
      end

      wait_cycles++;

      if (wait_cycles > WAIT_CYCLES + 100) begin
        $fatal(1, "APB read timeout: addr = 0x%02h", addr);
      end
    end

    // Return to IDLE.
    apb.driver_cb.PSEL    <= 1'b0;
    apb.driver_cb.PENABLE <= 1'b0;
  endtask : apb_read

  task automatic check_read(
    input logic [7:0]  addr,
    input logic [31:0] expected
  );
    logic [31:0] actual;
    logic        err;

    apb_read(addr, 3'b001, actual, err);

    if (err !== 1'b0) begin
      $fatal(1, "Read error: addr=0x%02h", addr);
    end

    if (actual !== expected) begin
      $fatal(
        1,
        "Read mismatch: addr=0x%02h expected=0x%08h actual=0x%08h",
        addr, expected, actual
      );
    end
  endtask : check_read


  initial begin
    // Initialize the bus through the driver clocking block.
    @(apb.driver_cb);
    apb.driver_cb.PSEL    <= 1'b0;
    apb.driver_cb.PENABLE <= 1'b0;
    apb.driver_cb.PADDR   <= 8'b0;
    apb.driver_cb.PWRITE  <= 1'b0;
    apb.driver_cb.PWDATA  <= 32'b0;
    apb.driver_cb.PSTRB   <= 4'b0;
    apb.driver_cb.PPROT   <= 3'b001;

    // Hold reset low for three more clock edges.
    repeat (3) @(apb.driver_cb);

    // Release reset away from the DUT's rising edge.
    @(negedge PCLK);
    PRESETn = 1'b1;

    // Observe reset released before starting tests.
    @(apb.driver_cb);

    // ------------------------------------------------------------
    // SMOKE TEST
    // ------------------------------------------------------------

    // ------------------------------------------------------------
    // 1. Reset values: check before modifying any registers.
    // ------------------------------------------------------------
    check_read(8'h00, 32'd0); // CTRL
    check_read(8'h04, 32'd0); // RELOAD
    check_read(8'h08, 32'd0); // COUNT
    check_read(8'h0C, 32'd0); // STATUS

    $display("PASS: register reset values");

    // ------------------------------------------------------------
    // 2. Full-byte write: establish a recognizable pattern.
    // ------------------------------------------------------------
    apb_write(8'h04, 32'h1122_3344, 4'b1111, 3'b001, slverr);

    if (slverr !== 1'b0) begin
      $fatal(1, "Full RELOAD write failed");
    end

    check_read(8'h04, 32'h1122_3344);

    $display("PASS: full RELOAD write/read");

    // ------------------------------------------------------------
    // 3. Partial write: update only bytes 2 and 0.
    // ------------------------------------------------------------
    apb_write(8'h04, 32'hAABB_CCDD, 4'b0101, 3'b001, slverr);

    if (slverr !== 1'b0) begin
      $fatal(1, "Partial RELOAD write failed");
    end

    check_read(8'h04, 32'h11BB_33DD);

    $display("PASS: partial-byte RELOAD write");

    // ------------------------------------------------------------
    // 4. Zero strobes: successful transfer, no register change.
    // ------------------------------------------------------------
    apb_write(8'h04, 32'hFFFF_FFFF, 4'b0000, 3'b001, slverr);

    if (slverr !== 1'b0) begin
      $fatal(1, "Zero-strobe RELOAD write failed");
    end

    check_read(8'h04, 32'h11BB_33DD);

    $display("PASS: zero-strobe RELOAD write");

    // ------------------------------------------------------------
    // 5. One-shot timer with interrupt enabled
    // ------------------------------------------------------------

    // RELOAD write to 5
    apb_write(8'h04, 32'd5, 4'b1111, 3'b001, slverr);
    if (slverr !== 1'b0) begin
      $fatal(1, "Timer RELOAD write failed");
    end

    // CTRL write to 0b101: IRQ enabled, one-shot mode, timer enabled
    apb_write(8'h00, 32'h0000_0005, 4'b0001, 3'b001, slverr);
    if (slverr !== 1'b0) begin
      $fatal(1, "Timer ENABLE write failed");
    end

    // The next five pre-edge samples must still show IRQ low.
    repeat (5) begin
      @(apb.monitor_cb);
      if (apb.monitor_cb.irq !== 1'b0) begin
        $fatal(1, "IRQ asserted too early or is unknown");
      end
    end

    // Expiry occurred at the previous edge.
    // Its updated IRQ is visible in this pre-edge sample.
    @(apb.monitor_cb);
    if (apb.monitor_cb.irq !== 1'b1) begin
      $fatal(1, "IRQ did not assert after expiry");
    end

    // One-shot expiry stops counting and clears enable.
    // IRQ enable remains set.
    check_read(8'h08, 32'd0);         // COUNT = 0
    check_read(8'h00, 32'h0000_0004); // CTRL = 100
    check_read(8'h0C, 32'd1);         // STATUS = 1

    $display("PASS: one-shot expiry and IRQ");

    // ------------------------------------------------------------
    // 6. STATUS: writing zero must not clear pending
    // ------------------------------------------------------------
    apb_write(8'h0C, 32'd0, 4'b0001, 3'b001, slverr);
    if (slverr !== 1'b0) begin
      $fatal(1, "STATUS write-zero failed");
    end

    check_read(8'h0C, 32'd1);

    @(apb.monitor_cb);
    if (apb.monitor_cb.irq !== 1'b1) begin
      $fatal(1, "IRQ did not remain asserted");
    end

    $display("PASS: STATUS write-zero preserves pending");

    // ------------------------------------------------------------
    // 7. STATUS: writing one clears pending and IRQ
    // ------------------------------------------------------------
    apb_write(8'h0C, 32'd1, 4'b0001, 3'b001, slverr);
    if (slverr !== 1'b0) begin
      $fatal(1, "STATUS clear failed");
    end

    // Sample after the clear has taken effect.
    @(apb.monitor_cb);
    if (apb.monitor_cb.irq !== 1'b0) begin
      $fatal(1, "IRQ did not clear");
    end

    check_read(8'h0C, 32'd0);

    $display("PASS: STATUS write-one-to-clear and IRQ clear");

    // ------------------------------------------------------------
    // 8. Unprivileged write must fail without changing RELOAD.
    // ------------------------------------------------------------
    apb_write(8'h04, 32'd99, 4'b1111, 3'b000, slverr);
    if (slverr !== 1'b1) begin
      $fatal(1, "Unprivileged write: expected PSLVERR = 1, got PSLVERR = %b", slverr);
    end

    check_read(8'h04, 32'd5);

    $display("PASS: unprivileged write rejected");

    // ------------------------------------------------------------
    // 9. Unprivileged reads are allowed.
    // ------------------------------------------------------------
    apb_read(8'h04, 3'b000, rdata, slverr);
    if (slverr !== 1'b0) begin
      $fatal(1, "Unprivileged read failed");
    end

    if (rdata !== 32'd5) begin
      $fatal(1, "Unprivileged read: expected PRDATA = 5, actual PRDATA = 0x%08h", rdata);
    end

    $display("PASS: unprivileged read allowed");

    // ------------------------------------------------------------
    // 10. COUNT is read-only.
    // ------------------------------------------------------------
    apb_write(8'h08, 32'd99, 4'b1111, 3'b001, slverr);
    if (slverr !== 1'b1) begin
      $fatal(1, "Expected error for COUNT write");
    end

    check_read(8'h08, 32'd0);

    $display("PASS: COUNT write rejected");

    // ------------------------------------------------------------
    // 11. Unmapped read must fail and return zero.
    // ------------------------------------------------------------
    apb_read(8'h10, 3'b001, rdata, slverr);
    if (slverr !== 1'b1) begin
      $fatal(1, "Expected error for unmapped read");
    end

    if (rdata !== 32'd0) begin
      $fatal(1, "Unmapped read should return zero");
    end

    $display("PASS: unmapped read rejected");

    // ------------------------------------------------------------
    // 12. Unaligned write must fail without modifying RELOAD.
    // ------------------------------------------------------------
    apb_write(8'h05, 32'hFFFF_FFFF, 4'b1111, 3'b001, slverr);
    if (slverr !== 1'b1) begin
      $fatal(1, "Expected error for unaligned write");
    end

    check_read(8'h04, 32'd5);

    $display("PASS: unaligned write rejected");

    // Allow final clocking-block observations before finishing.
    repeat (2) @(apb.driver_cb);
    
    $finish;
  end

endmodule : tb_top