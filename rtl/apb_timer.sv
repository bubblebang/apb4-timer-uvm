module apb_timer #(
  // Number of ACCESS wait cycles before completing each transfer
  parameter int unsigned WAIT_CYCLES = 0
) (
  input logic        PCLK,
  input logic        PRESETn,
  
  // APB request signals
  input logic [7:0]  PADDR,
  input logic        PSEL,
  input logic        PENABLE,
  input logic        PWRITE,
  input logic [31:0] PWDATA,
  input logic [3:0]  PSTRB,
  input logic [2:0]  PPROT,

  // APB response signals
  output logic [31:0] PRDATA,
  output logic        PREADY,
  output logic        PSLVERR,
  
  // Level interrupt: asserted while expiry is pending and unmasked
  output logic        irq
);
  
  // ------------------------------------------------------------------
  // Register map: local byte addresses, exact aligned accesses only
  // All registers reset to zero; reserved bits read as zero
  // ------------------------------------------------------------------ 
  localparam logic [7:0] CTRL_ADDR   = 8'h00; // RW: enable, periodic, IRQ enable
  localparam logic [7:0] RELOAD_ADDR = 8'h04; // RW: countdown reload value
  localparam logic [7:0] COUNT_ADDR  = 8'h08; // RO: current countdown value
  localparam logic [7:0] STATUS_ADDR = 8'h0C; // W1C: expiry pending, bit 0
  
  // Register storage
  logic [2:0]  ctrl_reg; // [0] enable, [1] periodic, [2] IRQ enable
  logic [31:0] reload_reg;
  logic [31:0] count_reg;
  logic        status_pending;

  // APB decode and write enables
  logic addr_valid;
  logic access_error;
  logic write_ok;
  logic reload_write;
  logic ctrl_write;
  logic status_clear;
  
  // Wait-state and timer control
  logic [31:0] wait_count;
  logic        timer_expire;
  
  // ------------------------------------------------------------------
  // Address decoding and access restrictions
  // ------------------------------------------------------------------
  // Address decoding
  assign addr_valid = (PADDR == CTRL_ADDR)   ||
                      (PADDR == RELOAD_ADDR) ||
                      (PADDR == COUNT_ADDR)  ||
                      (PADDR == STATUS_ADDR);
  
  // Access restrictions
  // Reject unmapped addresses, COUNT writes, and unprivileged writes
  // Reads allow either privilege level
  // PPROT[2:1] are ignored
  assign access_error = !addr_valid                       ||
                        (PWRITE && (PADDR == COUNT_ADDR)) ||
                        (PWRITE && !PPROT[0]);

  // ------------------------------------------------------------------
  // APB responses and successful-write decoding
  // ------------------------------------------------------------------
  // Ready only during ACCESS, after all wait cycles have elapsed
  assign PREADY = PRESETn && PSEL && PENABLE && (wait_count == 32'd0);

  // Report an error only during transfer completion
  assign PSLVERR = PSEL && PENABLE && PREADY && access_error;

  // Successful write transfer
  assign write_ok = PSEL && PENABLE && PREADY && PWRITE && !access_error;

  assign reload_write = write_ok && (PADDR == RELOAD_ADDR);

  // Only byte 0 contains implemented CTRL fields
  assign ctrl_write = write_ok && (PADDR == CTRL_ADDR) && PSTRB[0];

  // STATUS is write-one-to-clear
  assign status_clear = write_ok && (PADDR == STATUS_ADDR) && PSTRB[0] && PWDATA[0];
  
  // Combinational read mux
  // COUNT reads return its pre-edge value at the completing clock edge, before any countdown update
  always_comb begin
    PRDATA = 32'b0;
    if (PSEL && !PWRITE && !access_error) begin
      case(PADDR)
        CTRL_ADDR:   PRDATA = {29'b0, ctrl_reg};
        RELOAD_ADDR: PRDATA = reload_reg;
        COUNT_ADDR:  PRDATA = count_reg;
        STATUS_ADDR: PRDATA = {31'b0, status_pending};
        default:     PRDATA = 32'b0;
      endcase
    end
  end

  // ------------------------------------------------------------------
  // Timer event and interrupt
  // ------------------------------------------------------------------
  // An effective CTRL write suppresses counting and expiry on that edge
  assign timer_expire = !ctrl_write && ctrl_reg[0] && (count_reg == 32'd1);

  // Masking the interrupt does not clear the pending event
  assign irq = status_pending && ctrl_reg[2];
  
  // ------------------------------------------------------------------
  // Wait-state counter
  // ------------------------------------------------------------------
  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      wait_count <= '0;
    end
    else if (!PSEL) begin
      wait_count <= '0;
    end
    else if (!PENABLE) begin 
      // Load at the edge ending SETUP, including back-to-back transfers
      wait_count <= WAIT_CYCLES;
    end
    else if (wait_count > 32'd0) begin 
      // ACCESS
      wait_count <= wait_count - 32'd1;  
    end
  end

  // ------------------------------------------------------------------
  // RELOAD register: independent byte write enables
  // ------------------------------------------------------------------
  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      reload_reg <= '0;
    end
    else if (reload_write) begin
      // Unselected bytes retain their values; zero strobes are a no-op
      for (int i = 0; i < 4; i++) begin
        if (PSTRB[i]) begin
          reload_reg[i*8 +: 8] <= PWDATA[i*8 +: 8];
        end
      end
    end
  end

  // ------------------------------------------------------------------
  // CTRL register and COUNT register
  // Priority: reset > effective CTRL write > autonomous countdown
  // ------------------------------------------------------------------
  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      ctrl_reg  <= '0;
      count_reg <= '0;
    end
    else if (ctrl_write) begin
      ctrl_reg <= PWDATA[2:0];
      // ENABLE changes from 0 to 1: start a new countdown
      if (!ctrl_reg[0] && PWDATA[0]) begin
        count_reg <= reload_reg;
      end
      // Other CTRL writes hold COUNT for this edge.
    end
    else if (ctrl_reg[0] && (count_reg > 32'd0)) begin
      if (timer_expire) begin
        if (ctrl_reg[1]) begin
          // Periodic: reload immediately
          // If RELOAD is written on this edge, COUNT uses its old value
          count_reg <= reload_reg;
        end
        else begin
          // One-shot: stop after this expiry
          ctrl_reg[0] <= 1'b0;
          count_reg   <= '0;  
        end
      end
      else begin
        count_reg <= count_reg - 32'd1;
      end
    end
  end
  
  // ------------------------------------------------------------------
  // STATUS register: sticky expiry status
  // Priority: reset > expiry > software clear
  // ------------------------------------------------------------------
  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      status_pending <= 1'b0;
    end
    else if (timer_expire) begin
      status_pending <= 1'b1;
    end
    else if (status_clear) begin
      status_pending <= 1'b0;
    end
  end
              
endmodule : apb_timer