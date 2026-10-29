interface apb_if (
  input logic PCLK,
  input logic PRESETn
);

  // Request: driven by the testbench
  logic        PSEL;
  logic        PENABLE;
  logic [7:0]  PADDR;
  logic        PWRITE;
  logic [31:0] PWDATA;
  logic [3:0]  PSTRB;
  logic [2:0]  PPROT;
  
  // Response: driven by the DUT
  logic        PREADY;
  logic [31:0] PRDATA;
  logic        PSLVERR;
  logic        irq;

  // Reset coordination between the UVM test and tb_top.
  event reset_request;
  event reset_done;
  
  // Sample before the edge; drive requests after the edge.
  clocking driver_cb @(posedge PCLK);
    default input #1step output #0;

    input PRESETn;
    input PREADY, PRDATA, PSLVERR;

    output PSEL, PENABLE, PADDR, PWRITE;
    output PWDATA, PSTRB, PPROT;
  endclocking : driver_cb

  clocking monitor_cb @(posedge PCLK);
    default input #1step;
    
    input PRESETn;
    input PREADY, PRDATA, PSLVERR;
    input PSEL, PENABLE, PADDR, PWRITE;
    input PWDATA, PSTRB, PPROT;
    input irq;
  endclocking : monitor_cb

  // ------------------------------------------------------------
  // APB protocol assertions
  // These properties check this peripheral's local APB interface.
  // ------------------------------------------------------------

  // A selected SETUP must advance to ACCESS on the next clock.
  // Request fields must remain unchanged.
  property p_setup_to_access;
    @(posedge PCLK)
    disable iff (PRESETn !== 1'b1)
      (PSEL && !PENABLE)
      |=> (PSEL && PENABLE &&
          $stable({PADDR, PWRITE, PWDATA, PSTRB, PPROT}));
  endproperty : p_setup_to_access

  APB_SETUP_TO_ACCESS: assert property (p_setup_to_access)
    else $error("APB: SETUP did not advance to ACCESS with a stable request");


  // During a wait state, remain in ACCESS and hold the request.
  property p_wait_stable;
    @(posedge PCLK)
    disable iff (PRESETn !== 1'b1)
      (PSEL && PENABLE && !PREADY)
      |=> (PSEL && PENABLE &&
          $stable({PADDR, PWRITE, PWDATA, PSTRB, PPROT}));
  endproperty : p_wait_stable

  APB_WAIT_STABLE: assert property (p_wait_stable)
    else $error("APB: request changed or ACCESS ended during a wait state");


  // After completion, PENABLE must go low.
  // PSEL may stay high for a back-to-back transfer.
  property p_completion_ends_access;
    @(posedge PCLK)
    disable iff (PRESETn !== 1'b1)
      (PSEL && PENABLE && PREADY)
      |=> !PENABLE;
  endproperty : p_completion_ends_access

  APB_COMPLETION_ENDS_ACCESS: assert property (p_completion_ends_access)
    else $error("APB: PENABLE remained high after completion");


  // Read transfers must not assert write byte strobes.
  property p_read_strobes_zero;
    @(posedge PCLK)
    disable iff (PRESETn !== 1'b1)
      (PSEL && !PWRITE)
      |-> (PSTRB == 4'b0000);
  endproperty : p_read_strobes_zero

  APB_READ_STROBES_ZERO: assert property (p_read_strobes_zero)
    else $error("APB: PSTRB must be zero during reads");

endinterface : apb_if