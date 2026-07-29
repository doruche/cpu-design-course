`timescale 1ns / 1ps

// Characterizes the pipeline core through its fetch, data-access and Trace
// commit contracts. The controllable-latency memories deliberately avoid
// forcing or peeking at non-contract pipeline state.
module pipeline_control_tb;

    localparam integer IMEM_WORDS = 128;
    localparam integer DMEM_WORDS = 64;
    localparam integer MD_CAPTURE_RELEASE_BOUND = 8;
    localparam [31:0] NOP = 32'h0000_0013;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    wire        ifetch_req;
    wire [31:0] ifetch_addr;
    reg         ifetch_ready = 1'b1;
    reg         ifetch_valid = 1'b0;
    reg  [31:0] ifetch_inst = NOP;

    wire [ 3:0] daccess_ren;
    wire [31:0] daccess_addr;
    reg         daccess_rvalid = 1'b0;
    reg  [31:0] daccess_rdata = 32'h0;
    wire [ 3:0] daccess_wen;
    wire [31:0] daccess_wdata;
    reg         daccess_wresp = 1'b0;

    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem [0:DMEM_WORDS-1];
    integer fetch_delay [0:IMEM_WORDS-1];
    integer data_delay [0:DMEM_WORDS-1];

    reg         fetch_pending_model = 1'b0;
    reg  [31:0] fetch_address_model = 32'h0;
    integer     fetch_wait = 0;
    reg         data_pending_model = 1'b0;
    reg         data_write_model = 1'b0;
    reg  [31:0] data_address_model = 32'h0;
    reg  [ 3:0] data_wen_model = 4'h0;
    reg  [31:0] data_wdata_model = 32'h0;
    integer     data_wait = 0;

    integer commit_count [0:31];
    reg [31:0] commit_value [0:31];
    integer commit_cycle [0:31];
    integer fetch_count [0:IMEM_WORDS-1];
    integer fetch_request_cycle [0:IMEM_WORDS-1];
    integer fetch_last_request_cycle [0:IMEM_WORDS-1];
    integer fetch_response_cycle [0:IMEM_WORDS-1];
    integer fetch_stalled_response [0:IMEM_WORDS-1];
    integer data_response_cycle [0:DMEM_WORDS-1];
    integer fetch_request_count = 0;
    integer data_request_count = 0;
    integer read_request_count = 0;
    integer write_request_count = 0;
    integer visible_store_count = 0;
    integer buffered_fetch_stop_cycles = 0;
    integer stalled_fetch_response_count = 0;
    integer pause_after_stalled_response_cycles = 0;
    integer fetch_handoff_streak = 0;
    integer max_fetch_handoff_streak = 0;
    reg     saw_stalled_fetch_response = 1'b0;
    integer scenario_cycles = 0;
    string scenario_name = "reset";

    cpu_core dut (
        .cpu_rst       (rst),
        .cpu_clk       (clk),
        .ifetch_req    (ifetch_req),
        .ifetch_addr   (ifetch_addr),
        .ifetch_ready  (ifetch_ready),
        .ifetch_valid  (ifetch_valid),
        .ifetch_inst   (ifetch_inst),
        .daccess_ren   (daccess_ren),
        .daccess_addr  (daccess_addr),
        .daccess_rvalid(daccess_rvalid),
        .daccess_rdata (daccess_rdata),
        .daccess_wen   (daccess_wen),
        .daccess_wdata (daccess_wdata),
        .daccess_wresp (daccess_wresp)
    );

    task automatic check(input bit condition, input string message);
        begin
            if (!condition) begin
                $fatal(1, "pipeline-control [%s]: %s", scenario_name, message);
            end
        end
    endtask

    task automatic step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    function automatic [31:0] enc_addi(
        input [4:0] rd,
        input [4:0] rs1,
        input integer immediate
    );
        reg [11:0] imm;
        begin
            imm = immediate[11:0];
            enc_addi = {imm, rs1, 3'b000, rd, 7'b0010011};
        end
    endfunction

    function automatic [31:0] enc_add(
        input [4:0] rd,
        input [4:0] rs1,
        input [4:0] rs2
    );
        begin
            enc_add = {7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011};
        end
    endfunction

    function automatic [31:0] enc_mul(
        input [4:0] rd,
        input [4:0] rs1,
        input [4:0] rs2
    );
        begin
            enc_mul = {7'b0000001, rs2, rs1, 3'b000, rd, 7'b0110011};
        end
    endfunction

    function automatic [31:0] enc_div(
        input [4:0] rd,
        input [4:0] rs1,
        input [4:0] rs2
    );
        begin
            enc_div = {7'b0000001, rs2, rs1, 3'b100, rd, 7'b0110011};
        end
    endfunction

    function automatic [31:0] enc_lw(
        input [4:0] rd,
        input [4:0] rs1,
        input integer immediate
    );
        reg [11:0] imm;
        begin
            imm = immediate[11:0];
            enc_lw = {imm, rs1, 3'b010, rd, 7'b0000011};
        end
    endfunction

    function automatic [31:0] enc_sw(
        input [4:0] rs2,
        input [4:0] rs1,
        input integer immediate
    );
        reg [11:0] imm;
        begin
            imm = immediate[11:0];
            enc_sw = {imm[11:5], rs2, rs1, 3'b010,
                      imm[4:0], 7'b0100011};
        end
    endfunction

    function automatic [31:0] enc_beq(
        input [4:0] rs1,
        input [4:0] rs2,
        input integer offset
    );
        reg [12:0] imm;
        begin
            imm = offset[12:0];
            enc_beq = {imm[12], imm[10:5], rs2, rs1, 3'b000,
                       imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    function automatic [31:0] enc_jal(
        input [4:0] rd,
        input integer offset
    );
        reg [20:0] imm;
        begin
            imm = offset[20:0];
            enc_jal = {imm[20], imm[10:1], imm[11], imm[19:12],
                       rd, 7'b1101111};
        end
    endfunction

    function automatic [31:0] enc_jalr(
        input [4:0] rd,
        input [4:0] rs1,
        input integer immediate
    );
        reg [11:0] imm;
        begin
            imm = immediate[11:0];
            enc_jalr = {imm, rs1, 3'b000, rd, 7'b1100111};
        end
    endfunction

    task automatic prepare_scenario(input string name);
        integer index;
        begin
            @(negedge clk);
            rst = 1'b1;
            scenario_name = name;
            ifetch_ready = 1'b1;
            ifetch_valid = 1'b0;
            ifetch_inst = NOP;
            daccess_rvalid = 1'b0;
            daccess_rdata = 32'h0;
            daccess_wresp = 1'b0;
            fetch_pending_model = 1'b0;
            data_pending_model = 1'b0;
            fetch_request_count = 0;
            data_request_count = 0;
            read_request_count = 0;
            write_request_count = 0;
            visible_store_count = 0;
            buffered_fetch_stop_cycles = 0;
            stalled_fetch_response_count = 0;
            pause_after_stalled_response_cycles = 0;
            fetch_handoff_streak = 0;
            max_fetch_handoff_streak = 0;
            saw_stalled_fetch_response = 1'b0;
            scenario_cycles = 0;
            for (index = 0; index < IMEM_WORDS; index = index + 1) begin
                imem[index] = NOP;
                fetch_delay[index] = 0;
                fetch_count[index] = 0;
                fetch_request_cycle[index] = -1;
                fetch_last_request_cycle[index] = -1;
                fetch_response_cycle[index] = -1;
                fetch_stalled_response[index] = 0;
            end
            for (index = 0; index < DMEM_WORDS; index = index + 1) begin
                dmem[index] = 32'h0;
                data_delay[index] = 0;
                data_response_cycle[index] = -1;
            end
            for (index = 0; index < 32; index = index + 1) begin
                commit_count[index] = 0;
                commit_value[index] = 32'h0;
                commit_cycle[index] = -1;
            end
            repeat (3) step();
        end
    endtask

    task automatic start_scenario;
        begin
            @(negedge clk);
            rst = 1'b0;
        end
    endtask

    task automatic wait_for_commit(
        input integer rd,
        input [31:0] expected_value,
        input integer timeout_cycles
    );
        integer waited;
        begin
            waited = 0;
            while (commit_count[rd] == 0 && waited < timeout_cycles) begin
                step();
                waited = waited + 1;
            end
            check(commit_count[rd] == 1,
                  $sformatf("x%0d did not commit exactly once", rd));
            check(commit_value[rd] == expected_value,
                  $sformatf("x%0d committed %08x instead of %08x",
                            rd, commit_value[rd], expected_value));
        end
    endtask

    task automatic settle(input integer cycles);
        integer index;
        begin
            for (index = 0; index < cycles; index = index + 1) begin
                step();
            end
        end
    endtask

    // Fetch requests are sampled at the core edge. A zero-delay response is
    // presented from the following negative edge through the next positive
    // edge, allowing the core to consume it and issue its replacement on that
    // same edge. This exercises the one-response-per-cycle path needed by the
    // IF/ID plus skid pair without racing the DUT.
    always @(posedge clk) begin : fetch_model
        integer word_index;
        if (rst) begin
            ifetch_valid <= 1'b0;
            ifetch_inst <= NOP;
            fetch_pending_model <= 1'b0;
        end else begin
            if (ifetch_valid) begin
                word_index = fetch_address_model[8:2];
                if (fetch_response_cycle[word_index] < 0) begin
                    fetch_response_cycle[word_index] = scenario_cycles;
                end
                ifetch_valid <= 1'b0;
                fetch_pending_model <= 1'b0;
            end

            if (ifetch_req) begin
                check(!fetch_pending_model || ifetch_valid,
                      "a second fetch was issued before the first response");
                check(ifetch_addr[1:0] == 2'b00,
                      "fetch address was not word aligned");
                check(ifetch_addr < IMEM_WORDS * 4,
                      "fetch address exceeded the test instruction memory");
                word_index = ifetch_addr[8:2];
                fetch_pending_model <= 1'b1;
                fetch_address_model <= ifetch_addr;
                fetch_wait <= fetch_delay[word_index];
                fetch_request_count = fetch_request_count + 1;
                fetch_count[word_index] = fetch_count[word_index] + 1;
                if (fetch_request_cycle[word_index] < 0) begin
                    fetch_request_cycle[word_index] = scenario_cycles;
                end
                fetch_last_request_cycle[word_index] = scenario_cycles;
            end
        end
    end

    always @(negedge clk) begin : fetch_response_model
        integer word_index;
        if (rst) begin
            ifetch_valid <= 1'b0;
            ifetch_inst <= NOP;
        end else if (fetch_pending_model && !ifetch_valid) begin
            if (fetch_wait == 0) begin
                word_index = fetch_address_model[8:2];
                ifetch_inst <= imem[word_index];
                ifetch_valid <= 1'b1;
            end else begin
                fetch_wait <= fetch_wait - 1;
            end
        end
    end

    // Data responder with independently programmable latency per word. Any
    // duplicate request while one is pending is a protocol failure.
    always @(negedge clk) begin : data_model
        reg read_now;
        reg write_now;
        integer word_index;
        integer byte_index;
        read_now = daccess_ren != 4'h0;
        write_now = daccess_wen != 4'h0;

        if (rst) begin
            daccess_rvalid = 1'b0;
            daccess_rdata = 32'h0;
            daccess_wresp = 1'b0;
            data_pending_model = 1'b0;
        end else begin
            daccess_rvalid = 1'b0;
            daccess_wresp = 1'b0;

            if (data_pending_model) begin
                if (data_wait == 0) begin
                    word_index = data_address_model[7:2];
                    if (data_write_model) begin
                        for (byte_index = 0; byte_index < 4;
                             byte_index = byte_index + 1) begin
                            if (data_wen_model[byte_index]) begin
                                dmem[word_index][byte_index*8 +: 8] =
                                    data_wdata_model[byte_index*8 +: 8];
                            end
                        end
                        daccess_wresp = 1'b1;
                        visible_store_count = visible_store_count + 1;
                    end else begin
                        daccess_rdata = dmem[word_index];
                        daccess_rvalid = 1'b1;
                    end
                    data_response_cycle[word_index] = scenario_cycles;
                    data_pending_model = 1'b0;
                end else begin
                    data_wait = data_wait - 1;
                end
            end

            if (read_now || write_now) begin
                check(!(read_now && write_now),
                      "read and write requests were asserted together");
                check(!data_pending_model,
                      "a data request was repeated before its response");
                check(daccess_addr[1:0] == 2'b00,
                      "test scenarios expect word-aligned data accesses");
                check(daccess_addr < DMEM_WORDS * 4,
                      "data address exceeded the test memory");
                word_index = daccess_addr[7:2];
                data_pending_model = 1'b1;
                data_write_model = write_now;
                data_address_model = daccess_addr;
                data_wen_model = daccess_wen;
                data_wdata_model = daccess_wdata;
                data_wait = data_delay[word_index];
                data_request_count = data_request_count + 1;
                if (write_now) begin
                    write_request_count = write_request_count + 1;
                end else begin
                    read_request_count = read_request_count + 1;
                end
            end

            // With an outstanding data access and no fetch response in flight,
            // an idle request port demonstrates that IF_ID plus skid storage
            // have applied backpressure to fetch.
            if (data_pending_model && !fetch_pending_model && !ifetch_valid &&
                !ifetch_req && ifetch_ready) begin
                buffered_fetch_stop_cycles = buffered_fetch_stop_cycles + 1;
            end
        end
    end

    // Architectural observation uses only the RUN_TRACE public commit signals.
    always @(negedge clk) begin
        if (!rst && dut.debug_wb_rf_we && dut.debug_wb_rf_wR != 5'h0) begin
            if (commit_count[dut.debug_wb_rf_wR] == 0) begin
                commit_cycle[dut.debug_wb_rf_wR] = scenario_cycles;
            end
            commit_count[dut.debug_wb_rf_wR] =
                commit_count[dut.debug_wb_rf_wR] + 1;
            commit_value[dut.debug_wb_rf_wR] = dut.debug_wb_rf_wD;
        end

        if (!rst && dut.debug_mem_we != 4'h0) begin
            check(dut.debug_mem_we == daccess_wen,
                  "Trace memory write strobe disagreed with the data request");
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            scenario_cycles <= 0;
            fetch_handoff_streak = 0;
        end else begin
            scenario_cycles <= scenario_cycles + 1;
            if (ifetch_valid && ifetch_req) begin
                fetch_handoff_streak = fetch_handoff_streak + 1;
                if (fetch_handoff_streak > max_fetch_handoff_streak) begin
                    max_fetch_handoff_streak = fetch_handoff_streak;
                end
            end else begin
                fetch_handoff_streak = 0;
            end

            if (data_pending_model && ifetch_valid) begin
                stalled_fetch_response_count =
                    stalled_fetch_response_count + 1;
                fetch_stalled_response[fetch_address_model[8:2]] =
                    fetch_stalled_response[fetch_address_model[8:2]] + 1;
                saw_stalled_fetch_response = 1'b1;
            end

            if (data_pending_model && saw_stalled_fetch_response &&
                !ifetch_valid && !ifetch_req) begin
                pause_after_stalled_response_cycles =
                    pause_after_stalled_response_cycles + 1;
            end

            if (!data_pending_model) begin
                saw_stalled_fetch_response = 1'b0;
            end

            if (scenario_cycles > 2500) begin
                $fatal(1, "pipeline-control [%s]: timed out", scenario_name);
            end
        end
    end

    task automatic test_redirect_discard;
        begin
            prepare_scenario("redirect-discard");
            fetch_delay[0] = 2;
            imem[0]  = enc_addi(5'd1, 5'd0, 1);
            imem[1]  = enc_beq(5'd1, 5'd1, 16);
            imem[2]  = enc_addi(5'd20, 5'd0, 20);
            imem[3]  = enc_sw(5'd20, 5'd0, 0);
            imem[4]  = enc_addi(5'd23, 5'd0, 23);
            imem[5]  = enc_jal(5'd5, 16);
            imem[6]  = enc_addi(5'd21, 5'd0, 21);
            imem[7]  = enc_sw(5'd21, 5'd0, 4);
            imem[8]  = enc_addi(5'd24, 5'd0, 24);
            imem[9]  = enc_addi(5'd2, 5'd0, 56);
            imem[10] = enc_jalr(5'd6, 5'd2, 0);
            imem[11] = enc_addi(5'd22, 5'd0, 22);
            imem[12] = enc_sw(5'd22, 5'd0, 8);
            imem[13] = enc_addi(5'd25, 5'd0, 25);
            imem[14] = enc_addi(5'd3, 5'd0, 3);
            imem[15] = enc_jal(5'd0, 0);
            start_scenario();

            wait_for_commit(1, 32'd1, 200);
            wait_for_commit(5, 32'h0000_0018, 200);
            wait_for_commit(2, 32'd56, 200);
            wait_for_commit(6, 32'h0000_002c, 200);
            wait_for_commit(3, 32'd3, 200);
            settle(12);

            check(commit_count[20] == 0 && commit_count[21] == 0 &&
                  commit_count[22] == 0 && commit_count[23] == 0 &&
                  commit_count[24] == 0 && commit_count[25] == 0,
                  "an instruction from a redirected path committed");
            check(write_request_count == 0 && visible_store_count == 0,
                  "a redirected-path store became visible");
            check(fetch_count[3] > 0 && fetch_count[7] > 0 &&
                  fetch_count[12] > 0,
                  "redirect scenarios did not fetch each younger path");
            check(fetch_response_cycle[3] >= 0 &&
                  fetch_last_request_cycle[5] - fetch_response_cycle[3] >= 0 &&
                  fetch_last_request_cycle[5] - fetch_response_cycle[3] <= 1,
                  "branch wrong-path response was not adjacent to redirect fetch");
            check(fetch_response_cycle[7] >= 0 &&
                  fetch_last_request_cycle[9] - fetch_response_cycle[7] >= 0 &&
                  fetch_last_request_cycle[9] - fetch_response_cycle[7] <= 1,
                  "JAL wrong-path response was not adjacent to redirect fetch");
            check(fetch_response_cycle[12] >= 0 &&
                  fetch_last_request_cycle[14] - fetch_response_cycle[12] >= 0 &&
                  fetch_last_request_cycle[14] - fetch_response_cycle[12] <= 1,
                  "JALR wrong-path response was not adjacent to redirect fetch");
            $display("pipeline-control: redirect/discard PASS");
        end
    endtask

    task automatic test_load_dependencies;
        begin
            prepare_scenario("load-dependencies");
            dmem[16] = 32'd7;
            data_delay[16] = 4;
            data_delay[17] = 3;
            imem[0] = enc_addi(5'd1, 5'd0, 64);
            imem[1] = enc_lw(5'd2, 5'd1, 0);
            imem[2] = enc_add(5'd3, 5'd2, 5'd2);
            imem[3] = enc_lw(5'd4, 5'd1, 0);
            imem[4] = enc_sw(5'd4, 5'd1, 4);
            imem[5] = enc_lw(5'd5, 5'd1, 0);
            imem[6] = enc_beq(5'd5, 5'd2, 8);
            imem[7] = enc_addi(5'd23, 5'd0, 23);
            imem[8] = enc_addi(5'd6, 5'd0, 6);
            imem[9] = enc_jal(5'd0, 0);
            start_scenario();

            wait_for_commit(2, 32'd7, 300);
            wait_for_commit(3, 32'd14, 300);
            wait_for_commit(4, 32'd7, 300);
            wait_for_commit(5, 32'd7, 300);
            wait_for_commit(6, 32'd6, 300);
            settle(12);

            check(commit_count[23] == 0,
                  "load-dependent taken branch committed the wrong path");
            check(read_request_count == 3 && write_request_count == 1 &&
                  data_request_count == 4,
                  "load/store dependency program issued an unexpected request count");
            check(visible_store_count == 1 && dmem[17] == 32'd7,
                  "load-to-store forwarding wrote the wrong value or count");
            $display("pipeline-control: load dependencies PASS");
        end
    endtask

    task automatic test_forward_survives_mem_hold;
        begin
            prepare_scenario("forward-survives-mem-hold");
            dmem[16] = 32'h1234_5678;
            data_delay[16] = 12;
            imem[0] = enc_addi(5'd10, 5'd0, 9);
            imem[1] = enc_lw(5'd11, 5'd0, 64);
            imem[2] = enc_add(5'd12, 5'd10, 5'd10);
            imem[3] = enc_addi(5'd13, 5'd12, 1);
            imem[4] = enc_addi(5'd14, 5'd13, 1);
            imem[5] = enc_addi(5'd15, 5'd14, 1);
            imem[6] = enc_jal(5'd0, 0);
            start_scenario();

            wait_for_commit(11, 32'h1234_5678, 300);
            wait_for_commit(12, 32'd18, 300);
            wait_for_commit(13, 32'd19, 300);
            wait_for_commit(14, 32'd20, 300);
            wait_for_commit(15, 32'd21, 300);
            settle(8);

            check(read_request_count == 1 && data_request_count == 1,
                  "held pipeline repeated the blocking load");
            $display("pipeline-control: held-forward operand PASS");
        end
    endtask

    task automatic test_fetch_skid_capacity;
        begin
            prepare_scenario("fetch-skid-capacity");
            dmem[16] = 32'hcafe_babe;
            data_delay[16] = 20;
            // Delay the first younger fetch until the load has emptied IF/ID
            // and is holding MEM. The first stalled response can then occupy
            // IF/ID and issue its replacement; the second must occupy skid.
            fetch_delay[1] = 4;
            imem[0] = enc_lw(5'd1, 5'd0, 64);
            imem[1] = enc_addi(5'd16, 5'd0, 16);
            imem[2] = enc_addi(5'd17, 5'd0, 17);
            imem[3] = enc_addi(5'd18, 5'd0, 18);
            imem[4] = enc_addi(5'd19, 5'd0, 19);
            imem[5] = enc_addi(5'd20, 5'd0, 20);
            imem[6] = enc_jal(5'd0, 0);
            start_scenario();

            wait_for_commit(1, 32'hcafe_babe, 400);
            wait_for_commit(16, 32'd16, 400);
            wait_for_commit(17, 32'd17, 400);
            wait_for_commit(18, 32'd18, 400);
            wait_for_commit(19, 32'd19, 400);
            wait_for_commit(20, 32'd20, 400);
            settle(8);

            check(stalled_fetch_response_count >= 2,
                  "MEM hold did not accept both IF/ID and skid responses");
            check(fetch_stalled_response[1] == 1 &&
                  fetch_stalled_response[2] == 1,
                  "the two stalled responses were not the expected instructions");
            check(pause_after_stalled_response_cycles > 0 &&
                  buffered_fetch_stop_cycles > 0,
                  "fetch did not pause after both front-end slots filled");
            check(max_fetch_handoff_streak >= 3,
                  "fetch did not sustain consecutive response/issue handoffs");
            check(data_response_cycle[16] >= 0 &&
                  fetch_request_cycle[3] >= data_response_cycle[16],
                  "fetch did not resume after the two buffered entries drained");
            check(commit_count[16] == 1 && commit_count[17] == 1,
                  "the two responses accepted during MEM hold did not execute once");
            $display("pipeline-control: fetch handoff/skid capacity PASS");
        end
    endtask

    task automatic test_mul_div_behind_mem_hold;
        begin
            prepare_scenario("mul-div-behind-mem-hold");
            dmem[16] = 32'haaaa_5555;
            dmem[17] = 32'h5555_aaaa;
            data_delay[16] = 48;
            data_delay[17] = 48;
            imem[0] = enc_addi(5'd4, 5'd0, 6);
            imem[1] = enc_addi(5'd5, 5'd0, 7);
            imem[2] = enc_lw(5'd1, 5'd0, 64);
            imem[3] = enc_mul(5'd6, 5'd4, 5'd5);
            imem[4] = enc_addi(5'd7, 5'd6, 1);
            imem[5] = enc_lw(5'd2, 5'd0, 68);
            imem[6] = enc_div(5'd8, 5'd6, 5'd4);
            imem[7] = enc_addi(5'd9, 5'd8, 1);
            imem[8] = enc_jal(5'd0, 0);
            start_scenario();

            wait_for_commit(6, 32'd42, 900);
            wait_for_commit(7, 32'd43, 900);
            wait_for_commit(8, 32'd7, 900);
            wait_for_commit(9, 32'd8, 900);
            settle(12);

            check(commit_count[6] == 1 && commit_count[8] == 1,
                  "mul/div result committed more than once");
            // Both iterative units need far more than this many cycles from a
            // fresh launch. A commit inside this release window therefore
            // proves that completion was captured while the older MEM access
            // still held EX, while leaving slack for normal stage movement.
            check(data_response_cycle[16] >= 0 &&
                  commit_cycle[6] >= data_response_cycle[16] &&
                  commit_cycle[6] - data_response_cycle[16] <=
                      MD_CAPTURE_RELEASE_BOUND,
                  "multiply did not complete and capture behind the MEM hold");
            check(data_response_cycle[17] >= 0 &&
                  commit_cycle[8] >= data_response_cycle[17] &&
                  commit_cycle[8] - data_response_cycle[17] <=
                      MD_CAPTURE_RELEASE_BOUND,
                  "divide did not complete and capture behind the MEM hold");
            check(read_request_count == 2 && data_request_count == 2,
                  "mul/div overlap repeated a blocking load");
            $display("pipeline-control: mul/div completion overlap PASS");
        end
    endtask

    task automatic test_flush_after_mem_stall;
        begin
            prepare_scenario("flush-after-mem-stall");
            dmem[16] = 32'hfeed_face;
            data_delay[16] = 16;
            imem[0] = enc_addi(5'd1, 5'd0, 1);
            imem[1] = enc_lw(5'd2, 5'd0, 64);
            imem[2] = enc_beq(5'd1, 5'd1, 12);
            imem[3] = enc_sw(5'd1, 5'd0, 8);
            imem[4] = enc_addi(5'd24, 5'd0, 24);
            imem[5] = enc_addi(5'd3, 5'd0, 3);
            imem[6] = enc_jal(5'd0, 0);
            start_scenario();

            wait_for_commit(2, 32'hfeed_face, 400);
            wait_for_commit(3, 32'd3, 400);
            settle(12);

            check(commit_count[24] == 0,
                  "a branch held behind MEM committed the wrong path");
            check(write_request_count == 0 && visible_store_count == 0,
                  "flush/stall priority allowed a wrong-path store");
            check(read_request_count == 1 && data_request_count == 1,
                  "flush/stall scenario repeated its blocking load");
            $display("pipeline-control: flush/stall/response priority PASS");
        end
    endtask

    initial begin
        test_redirect_discard();
        test_load_dependencies();
        test_fetch_skid_capacity();
        test_forward_survives_mem_hold();
        test_mul_div_behind_mem_hold();
        test_flush_after_mem_stall();
        $display("pipeline_control_tb: PASS (6 scenarios, 7 contract groups)");
        $finish;
    end

endmodule
