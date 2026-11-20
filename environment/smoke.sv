`timescale 1ns/1ps
module smoke;
    logic clk = 0, rst_n = 0;
    logic in_valid = 0, in_ready, in_decrypt = 0;
    logic [127:0] in_key = 0, in_block = 0;
    logic out_valid, out_ready = 1;
    logic [127:0] out_block;
    aes128 dut (.*);
    always #5 clk = ~clk;

    task automatic check_block(
        input bit decrypt,
        input logic [127:0] block,
        input logic [127:0] expected,
        input integer limit,
        input string label
    );
        integer cycles;
        @(negedge clk);
        in_valid = 1;
        in_decrypt = decrypt;
        in_block = block;
        #1;
        if (in_ready !== 1'b1) $fatal(1, "%s: core not ready", label);
        @(posedge clk);
        #1;
        in_valid = 0;
        cycles = 0;
        while (out_valid !== 1'b1 && cycles < limit) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
        end
        if (out_valid !== 1'b1) $fatal(1, "%s: output exceeded %0d cycles", label, limit);
        if (out_block !== expected) $fatal(1, "%s: got %032h expected %032h", label, out_block, expected);
        $display("SMOKE %s latency=%0d", label, cycles);
        @(posedge clk);
        #1;
    endtask

    localparam logic [127:0] P = 128'h00112233445566778899aabbccddeeff;
    localparam logic [127:0] C = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
    initial begin
        @(posedge clk);
        #1;
        rst_n = 1;
        in_key = 128'h000102030405060708090a0b0c0d0e0f;
        check_block(0, P, C, 160, "encrypt");
        check_block(1, C, P, 190, "cold-decrypt");
        check_block(1, C, P, 155, "warm-decrypt");
        $display("SMOKE PASS");
        $finish;
    end
endmodule
