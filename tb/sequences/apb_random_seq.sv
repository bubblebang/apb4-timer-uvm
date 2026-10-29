class apb_random_seq extends apb_base_seq;

  `uvm_object_utils(apb_random_seq)

  int unsigned num_transfers = 300;

  function new(string name = "apb_random_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    apb_transaction tr;
    logic [31:0]    rdata;

    // Establish a known starting state.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b1, 32'd1, rdata);
    access_reg(8'h04, 1'b1, 32'd5, rdata);

    repeat (num_transfers) begin
      tr = apb_transaction::type_id::create("tr");

      start_item(tr);

      if (!tr.randomize() with {
        // Favor implemented registers, while exercising invalid addresses.
        addr dist {
          8'h00 := 20,
          8'h04 := 20,
          8'h08 := 15,
          8'h0C := 20,
          8'h05 := 5,
          8'h10 := 5,
          [8'h11:8'hFF] :/ 15
        };

        // Favor privileged accesses, but retain negative testing.
        prot[0] dist {0 := 1, 1 := 3};

        // Small reload values allow expiry during random traffic.
        if (write && (addr == 8'h04))
          wdata inside {[0:20]};

        // Exercise all timer control combinations.
        if (write && (addr == 8'h00))
          wdata inside {[0:7]};

        // Exercise both STATUS write-zero and write-one.
        if (write && (addr == 8'h0C))
          wdata inside {[0:1]};
      }) begin
        `uvm_fatal("RAND_FAILED", "APB transaction randomization failed")
      end

      finish_item(tr);

      if (tr.aborted) begin
        `uvm_fatal(
          "UNEXPECTED_ABORT",
          "Random transfer was unexpectedly aborted by reset"
        )
      end

      // PSLVERR may legitimately be 0 or 1.
      // The scoreboard independently checks which response is correct.
      if ($isunknown(tr.slverr)) begin
        `uvm_fatal("RESPONSE_X", "Random transfer returned unknown PSLVERR")
      end
    end

    // Stop the timer before clearing pending status.
    access_reg(8'h00, 1'b1, 32'd0, rdata);
    access_reg(8'h0C, 1'b1, 32'd1, rdata);

    // Allow a subsequent observation to check the final IRQ state.
    access_reg(8'h0C, 1'b0, 32'd0, rdata);
    if (rdata !== 32'd0) begin
      `uvm_fatal("CLEANUP_FAILED", "STATUS did not clear")
    end

    `uvm_info(
      "APB_RANDOM",
      $sformatf("Completed %0d random transfers", num_transfers),
      UVM_LOW
    )
  endtask : body

endclass : apb_random_seq