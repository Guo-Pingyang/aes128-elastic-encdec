`timescale 1ns/1ps
module aes128_tb;
    localparam integer BLOCKS = 15, STREAM = 16, VECTOR_COUNT = BLOCKS + STREAM;
    localparam integer ENC_LIMIT = 160, COLD_LIMIT = 190, WARM_LIMIT = 155;

    logic clk = 0, rst_n = 0;
    logic in_valid = 0, in_ready, in_decrypt = 0;
    logic [127:0] in_key = 0, in_block = 0;
    logic out_valid, out_ready = 1;
    logic [127:0] out_block;
    aes128 dut (.*);
    always #5 clk = ~clk;

    logic [383:0] vectors [0:VECTOR_COUNT-1];
    logic [127:0] expected_input, expected_fifo [0:VECTOR_COUNT-1];
    logic [127:0] held_block;
    bit accepted, retired, held = 0;
    integer head = 0, tail = 0, retired_total = 0;
    integer max_latency = 0, warm_max_latency = 0;
    string suite;

    task automatic tick;
        @(posedge clk);
        accepted = 0;
        retired = 0;
        if (!rst_n) begin
            held = 0;
            head = 0;
            tail = 0;
        end else begin
            if ((in_ready !== 0 && in_ready !== 1) || (out_valid !== 0 && out_valid !== 1))
                $fatal(1, "TB_FAIL %s unknown handshake flag", suite);
            if (held && (!out_valid || out_block !== held_block))
                $fatal(1, "TB_FAIL %s output changed before a stalled transfer", suite);
            if (out_valid) begin
                if (head == tail) $fatal(1, "TB_FAIL %s spurious output", suite);
                if (out_block !== expected_fifo[head])
                    $fatal(1, "TB_FAIL %s block %0d mismatch got=%032h expected=%032h",
                           suite, head, out_block, expected_fifo[head]);
                if (out_ready) begin
                    head = head + 1;
                    retired_total = retired_total + 1;
                    retired = 1;
                end
            end
            held = out_valid && !out_ready;
            if (held) held_block = out_block;
            if (in_ready && in_valid) begin
                if (tail >= VECTOR_COUNT) $fatal(1, "TB_FAIL scoreboard overflow");
                expected_fifo[tail] = expected_input;
                tail = tail + 1;
                accepted = 1;
            end
        end
        #1;
        if (!rst_n && (out_valid !== 0 || in_ready !== 1))
            $fatal(1, "TB_FAIL %s reset did not clear the interface", suite);
    endtask

    task automatic drive(input integer row, input bit decrypt);
        in_valid = 1;
        in_decrypt = decrypt;
        in_key = vectors[row][383:256];
        in_block = decrypt ? vectors[row][127:0] : vectors[row][255:128];
        expected_input = decrypt ? vectors[row][255:128] : vectors[row][127:0];
    endtask

    task automatic perturb_idle;
        in_valid = 0;
        in_decrypt = ~in_decrypt;
        in_key = {in_key[126:0], ~in_key[127]};
        in_block = {in_block[126:0], ~in_block[127]};
    endtask

    task automatic submit(input integer row, input bit decrypt, input string reason);
        drive(row, decrypt);
        tick();
        if (!accepted) $fatal(1, "TB_FAIL %s did not accept %s", suite, reason);
        in_valid = 0;
    endtask

    task automatic wait_visible(input integer limit, input bit warm);
        integer cycles;
        cycles = 0;
        while (out_valid !== 1'b1 && cycles < limit) begin
            perturb_idle();
            tick();
            cycles = cycles + 1;
        end
        if (out_valid !== 1'b1)
            $fatal(1, "TB_FAIL %s output exceeded %0d cycles (warm=%0d)", suite, limit, warm);
        if (cycles > max_latency) max_latency = cycles;
        if (warm && cycles > warm_max_latency) warm_max_latency = cycles;
    endtask

    task automatic isolated(input integer row, input bit decrypt, input integer limit, input bit warm);
        if (head != tail || out_valid) $fatal(1, "TB_FAIL %s core not drained", suite);
        submit(row, decrypt, "an idle request");
        wait_visible(limit, warm);
        tick();
        if (!retired) $fatal(1, "TB_FAIL %s expected output transfer", suite);
    endtask

    task automatic overlap(input bit first_decrypt);
        out_ready = 0;
        submit(0, first_decrypt, "the first request");
        wait_visible(first_decrypt ? COLD_LIMIT : ENC_LIMIT, 0);
        submit(1, !first_decrypt, "a second request behind the stalled first result");
        repeat (COLD_LIMIT) begin
            perturb_idle();
            tick();
        end
        out_ready = 1;
        drive(2, first_decrypt);
        tick();
        if (!retired || !accepted)
            $fatal(1, "TB_FAIL overlap release must retire the head and accept the third request");
        in_valid = 0;
        if (out_valid !== 1'b1 || out_block !== expected_fifo[head])
            $fatal(1, "TB_FAIL overlap stalled head was not replaced without a bubble");
        tick();
        if (!retired) $fatal(1, "TB_FAIL overlap second transfer missing");
        wait_visible((first_decrypt ? COLD_LIMIT : ENC_LIMIT) - 1, 0);
        tick();
        if (!retired) $fatal(1, "TB_FAIL overlap third transfer missing");
    endtask

    task automatic reset_stalled;
        logic ready_before;
        logic [127:0] block_before;
        out_ready = 0;
        submit(0, 0, "the request before reset");
        wait_visible(ENC_LIMIT, 0);
        // Start another operation if the interface offers a slot while the
        // head is blocked. The overlap suite checks that this slot is required.
        if (in_ready) submit(2, 1, "a request before reset");
        repeat (7) tick();
        ready_before = in_ready;
        block_before = out_block;
        @(negedge clk);
        rst_n = 0;
        #1;
        if (out_valid !== 1'b1 || out_block !== block_before || in_ready !== ready_before)
            $fatal(1, "TB_FAIL reset changed interface before the rising edge");
        tick();
        rst_n = 1;
        out_ready = 1;
        repeat (COLD_LIMIT + 5) tick();
        isolated(0, 1, COLD_LIMIT, 0);
        isolated(1, 0, ENC_LIMIT, 0);
    endtask

    task automatic stream_mixed;
        integer sent;
        integer cycle;
        logic [31:0] schedule;
        sent = 0;
        cycle = 0;
        schedule = 32'hd43719ac;
        while (retired_total < STREAM && cycle < 11000) begin
            schedule = {schedule[30:0], schedule[31] ^ schedule[21] ^ schedule[1] ^ schedule[0]};
            // Include both short stalls and stalls longer than a block.
            out_ready = ((cycle % 487) >= 211) && (schedule[3:0] != 0);
            if (sent < STREAM)
                drive(BLOCKS + sent, (sent % 4) != 2);
            else
                perturb_idle();
            tick();
            if (accepted) sent = sent + 1;
            cycle = cycle + 1;
        end
        if (retired_total != STREAM || sent != STREAM)
            $fatal(1, "TB_FAIL stream progress sent=%0d received=%0d", sent, retired_total);
        in_valid = 0;
        out_ready = 1;
    endtask

    integer index;
    initial begin
        if (!$value$plusargs("suite=%s", suite)) $fatal(1, "TB_FAIL missing suite");
        $readmemh("vectors.mem", vectors);
        // Inputs that would be handshakes on a normal edge are ignored on reset.
        drive(0, 0);
        tick();
        rst_n = 1;
        in_valid = 0;

        if (suite == "encrypt") begin
            for (index = 0; index < BLOCKS; index = index + 1)
                isolated(index, 0, ENC_LIMIT, 0);
        end else if (suite == "decrypt") begin
            for (index = 0; index < BLOCKS; index = index + 1)
                isolated(index, 1, COLD_LIMIT, 0);
        end else if (suite == "warm") begin
            for (index = 0; index < 8; index = index + 1)
                isolated(BLOCKS + index, 1,
                         (index % 2) ? WARM_LIMIT : COLD_LIMIT, (index % 2) != 0);
        end else if (suite == "overlap") begin
            overlap(0);
            overlap(1);
        end else if (suite == "reset") begin
            reset_stalled();
        end else if (suite == "stream") begin
            stream_mixed();
        end else begin
            $fatal(1, "TB_FAIL unknown suite %s", suite);
        end

        repeat (5) tick();
        if (head != tail || out_valid) $fatal(1, "TB_FAIL %s did not drain", suite);
        $display("TB_PASS suite=%s blocks=%0d max_latency=%0d warm_max_latency=%0d",
                 suite, retired_total, max_latency, warm_max_latency);
        $finish;
    end
endmodule
