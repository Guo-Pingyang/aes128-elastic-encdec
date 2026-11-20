module aes128 (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         in_valid,
    output logic         in_ready,
    input  logic         in_decrypt,
    input  logic [127:0] in_key,
    input  logic [127:0] in_block,
    output logic         out_valid,
    input  logic         out_ready,
    output logic [127:0] out_block
);


    function automatic logic [7:0] sbox(input logic [7:0] x);
        logic [7:0] y;
        begin
            case (x[7:4])
                4'h0: case (x[3:0])
                    4'h0: y = 8'h63; 4'h1: y = 8'h7c; 4'h2: y = 8'h77; 4'h3: y = 8'h7b;
                    4'h4: y = 8'hf2; 4'h5: y = 8'h6b; 4'h6: y = 8'h6f; 4'h7: y = 8'hc5;
                    4'h8: y = 8'h30; 4'h9: y = 8'h01; 4'ha: y = 8'h67; 4'hb: y = 8'h2b;
                    4'hc: y = 8'hfe; 4'hd: y = 8'hd7; 4'he: y = 8'hab; 4'hf: y = 8'h76;
                endcase
                4'h1: case (x[3:0])
                    4'h0: y = 8'hca; 4'h1: y = 8'h82; 4'h2: y = 8'hc9; 4'h3: y = 8'h7d;
                    4'h4: y = 8'hfa; 4'h5: y = 8'h59; 4'h6: y = 8'h47; 4'h7: y = 8'hf0;
                    4'h8: y = 8'had; 4'h9: y = 8'hd4; 4'ha: y = 8'ha2; 4'hb: y = 8'haf;
                    4'hc: y = 8'h9c; 4'hd: y = 8'ha4; 4'he: y = 8'h72; 4'hf: y = 8'hc0;
                endcase
                4'h2: case (x[3:0])
                    4'h0: y = 8'hb7; 4'h1: y = 8'hfd; 4'h2: y = 8'h93; 4'h3: y = 8'h26;
                    4'h4: y = 8'h36; 4'h5: y = 8'h3f; 4'h6: y = 8'hf7; 4'h7: y = 8'hcc;
                    4'h8: y = 8'h34; 4'h9: y = 8'ha5; 4'ha: y = 8'he5; 4'hb: y = 8'hf1;
                    4'hc: y = 8'h71; 4'hd: y = 8'hd8; 4'he: y = 8'h31; 4'hf: y = 8'h15;
                endcase
                4'h3: case (x[3:0])
                    4'h0: y = 8'h04; 4'h1: y = 8'hc7; 4'h2: y = 8'h23; 4'h3: y = 8'hc3;
                    4'h4: y = 8'h18; 4'h5: y = 8'h96; 4'h6: y = 8'h05; 4'h7: y = 8'h9a;
                    4'h8: y = 8'h07; 4'h9: y = 8'h12; 4'ha: y = 8'h80; 4'hb: y = 8'he2;
                    4'hc: y = 8'heb; 4'hd: y = 8'h27; 4'he: y = 8'hb2; 4'hf: y = 8'h75;
                endcase
                4'h4: case (x[3:0])
                    4'h0: y = 8'h09; 4'h1: y = 8'h83; 4'h2: y = 8'h2c; 4'h3: y = 8'h1a;
                    4'h4: y = 8'h1b; 4'h5: y = 8'h6e; 4'h6: y = 8'h5a; 4'h7: y = 8'ha0;
                    4'h8: y = 8'h52; 4'h9: y = 8'h3b; 4'ha: y = 8'hd6; 4'hb: y = 8'hb3;
                    4'hc: y = 8'h29; 4'hd: y = 8'he3; 4'he: y = 8'h2f; 4'hf: y = 8'h84;
                endcase
                4'h5: case (x[3:0])
                    4'h0: y = 8'h53; 4'h1: y = 8'hd1; 4'h2: y = 8'h00; 4'h3: y = 8'hed;
                    4'h4: y = 8'h20; 4'h5: y = 8'hfc; 4'h6: y = 8'hb1; 4'h7: y = 8'h5b;
                    4'h8: y = 8'h6a; 4'h9: y = 8'hcb; 4'ha: y = 8'hbe; 4'hb: y = 8'h39;
                    4'hc: y = 8'h4a; 4'hd: y = 8'h4c; 4'he: y = 8'h58; 4'hf: y = 8'hcf;
                endcase
                4'h6: case (x[3:0])
                    4'h0: y = 8'hd0; 4'h1: y = 8'hef; 4'h2: y = 8'haa; 4'h3: y = 8'hfb;
                    4'h4: y = 8'h43; 4'h5: y = 8'h4d; 4'h6: y = 8'h33; 4'h7: y = 8'h85;
                    4'h8: y = 8'h45; 4'h9: y = 8'hf9; 4'ha: y = 8'h02; 4'hb: y = 8'h7f;
                    4'hc: y = 8'h50; 4'hd: y = 8'h3c; 4'he: y = 8'h9f; 4'hf: y = 8'ha8;
                endcase
                4'h7: case (x[3:0])
                    4'h0: y = 8'h51; 4'h1: y = 8'ha3; 4'h2: y = 8'h40; 4'h3: y = 8'h8f;
                    4'h4: y = 8'h92; 4'h5: y = 8'h9d; 4'h6: y = 8'h38; 4'h7: y = 8'hf5;
                    4'h8: y = 8'hbc; 4'h9: y = 8'hb6; 4'ha: y = 8'hda; 4'hb: y = 8'h21;
                    4'hc: y = 8'h10; 4'hd: y = 8'hff; 4'he: y = 8'hf3; 4'hf: y = 8'hd2;
                endcase
                4'h8: case (x[3:0])
                    4'h0: y = 8'hcd; 4'h1: y = 8'h0c; 4'h2: y = 8'h13; 4'h3: y = 8'hec;
                    4'h4: y = 8'h5f; 4'h5: y = 8'h97; 4'h6: y = 8'h44; 4'h7: y = 8'h17;
                    4'h8: y = 8'hc4; 4'h9: y = 8'ha7; 4'ha: y = 8'h7e; 4'hb: y = 8'h3d;
                    4'hc: y = 8'h64; 4'hd: y = 8'h5d; 4'he: y = 8'h19; 4'hf: y = 8'h73;
                endcase
                4'h9: case (x[3:0])
                    4'h0: y = 8'h60; 4'h1: y = 8'h81; 4'h2: y = 8'h4f; 4'h3: y = 8'hdc;
                    4'h4: y = 8'h22; 4'h5: y = 8'h2a; 4'h6: y = 8'h90; 4'h7: y = 8'h88;
                    4'h8: y = 8'h46; 4'h9: y = 8'hee; 4'ha: y = 8'hb8; 4'hb: y = 8'h14;
                    4'hc: y = 8'hde; 4'hd: y = 8'h5e; 4'he: y = 8'h0b; 4'hf: y = 8'hdb;
                endcase
                4'ha: case (x[3:0])
                    4'h0: y = 8'he0; 4'h1: y = 8'h32; 4'h2: y = 8'h3a; 4'h3: y = 8'h0a;
                    4'h4: y = 8'h49; 4'h5: y = 8'h06; 4'h6: y = 8'h24; 4'h7: y = 8'h5c;
                    4'h8: y = 8'hc2; 4'h9: y = 8'hd3; 4'ha: y = 8'hac; 4'hb: y = 8'h62;
                    4'hc: y = 8'h91; 4'hd: y = 8'h95; 4'he: y = 8'he4; 4'hf: y = 8'h79;
                endcase
                4'hb: case (x[3:0])
                    4'h0: y = 8'he7; 4'h1: y = 8'hc8; 4'h2: y = 8'h37; 4'h3: y = 8'h6d;
                    4'h4: y = 8'h8d; 4'h5: y = 8'hd5; 4'h6: y = 8'h4e; 4'h7: y = 8'ha9;
                    4'h8: y = 8'h6c; 4'h9: y = 8'h56; 4'ha: y = 8'hf4; 4'hb: y = 8'hea;
                    4'hc: y = 8'h65; 4'hd: y = 8'h7a; 4'he: y = 8'hae; 4'hf: y = 8'h08;
                endcase
                4'hc: case (x[3:0])
                    4'h0: y = 8'hba; 4'h1: y = 8'h78; 4'h2: y = 8'h25; 4'h3: y = 8'h2e;
                    4'h4: y = 8'h1c; 4'h5: y = 8'ha6; 4'h6: y = 8'hb4; 4'h7: y = 8'hc6;
                    4'h8: y = 8'he8; 4'h9: y = 8'hdd; 4'ha: y = 8'h74; 4'hb: y = 8'h1f;
                    4'hc: y = 8'h4b; 4'hd: y = 8'hbd; 4'he: y = 8'h8b; 4'hf: y = 8'h8a;
                endcase
                4'hd: case (x[3:0])
                    4'h0: y = 8'h70; 4'h1: y = 8'h3e; 4'h2: y = 8'hb5; 4'h3: y = 8'h66;
                    4'h4: y = 8'h48; 4'h5: y = 8'h03; 4'h6: y = 8'hf6; 4'h7: y = 8'h0e;
                    4'h8: y = 8'h61; 4'h9: y = 8'h35; 4'ha: y = 8'h57; 4'hb: y = 8'hb9;
                    4'hc: y = 8'h86; 4'hd: y = 8'hc1; 4'he: y = 8'h1d; 4'hf: y = 8'h9e;
                endcase
                4'he: case (x[3:0])
                    4'h0: y = 8'he1; 4'h1: y = 8'hf8; 4'h2: y = 8'h98; 4'h3: y = 8'h11;
                    4'h4: y = 8'h69; 4'h5: y = 8'hd9; 4'h6: y = 8'h8e; 4'h7: y = 8'h94;
                    4'h8: y = 8'h9b; 4'h9: y = 8'h1e; 4'ha: y = 8'h87; 4'hb: y = 8'he9;
                    4'hc: y = 8'hce; 4'hd: y = 8'h55; 4'he: y = 8'h28; 4'hf: y = 8'hdf;
                endcase
                4'hf: case (x[3:0])
                    4'h0: y = 8'h8c; 4'h1: y = 8'ha1; 4'h2: y = 8'h89; 4'h3: y = 8'h0d;
                    4'h4: y = 8'hbf; 4'h5: y = 8'he6; 4'h6: y = 8'h42; 4'h7: y = 8'h68;
                    4'h8: y = 8'h41; 4'h9: y = 8'h99; 4'ha: y = 8'h2d; 4'hb: y = 8'h0f;
                    4'hc: y = 8'hb0; 4'hd: y = 8'h54; 4'he: y = 8'hbb; 4'hf: y = 8'h16;
                endcase
            endcase
            sbox = y;
        end
    endfunction

    localparam logic [3:0] ST_IDLE  = 4'd0;
    localparam logic [3:0] ST_KEY0  = 4'd1;
    localparam logic [3:0] ST_KEY1  = 4'd2;
    localparam logic [3:0] ST_KEY2  = 4'd3;
    localparam logic [3:0] ST_SUB   = 4'd4;
    localparam logic [3:0] ST_SHIFT = 4'd5;
    localparam logic [3:0] ST_COL   = 4'd6;
    localparam logic [3:0] ST_DONE  = 4'd7;

    logic [3:0]  st;
    logic [127:0] state_reg;
    logic [127:0] round_key;
    logic [31:0] subword_reg;
    logic [3:0]  round_cnt;
    logic [2:0]  sub_cnt;
    logic [1:0]  col_cnt;
    logic [7:0]  rcon;

    logic [7:0] sb0_in, sb1_in, sb0_out, sb1_out;

    always_comb begin
        sb0_in = 8'h00;
        sb1_in = 8'h00;
        case (st)
            ST_KEY0: begin
                sb0_in = round_key[23:16];
                sb1_in = round_key[15:8];
            end
            ST_KEY1: begin
                sb0_in = round_key[7:0];
                sb1_in = round_key[31:24];
            end
            ST_SUB: begin
                sb0_in = state_reg[127:120];
                sb1_in = state_reg[119:112];
            end
            default: begin
                sb0_in = 8'h00;
                sb1_in = 8'h00;
            end
        endcase
    end

    assign sb0_out = sbox(sb0_in);
    assign sb1_out = sbox(sb1_in);

    function automatic logic [7:0] xtime(input logic [7:0] x);
        logic [7:0] y;
        begin
            y = {x[6:0], 1'b0};
            if (x[7]) y = y ^ 8'h1b;
            xtime = y;
        end
    endfunction

    logic [7:0] a0, a1, a2, a3;
    logic [7:0] t, b0, b1, b2, b3;
    logic [31:0] col_in, col_out, col_key;

    always_comb begin
        col_in = state_reg[127:96];
        {a0, a1, a2, a3} = col_in;
        case (col_cnt)
            2'd0: col_key = round_key[127:96];
            2'd1: col_key = round_key[95:64];
            2'd2: col_key = round_key[63:32];
            default: col_key = round_key[31:0];
        endcase
        t = a0 ^ a1 ^ a2 ^ a3;
        b0 = a0 ^ t ^ xtime(a0 ^ a1);
        b1 = a1 ^ t ^ xtime(a1 ^ a2);
        b2 = a2 ^ t ^ xtime(a2 ^ a3);
        b3 = a3 ^ t ^ xtime(a3 ^ a0);
        if (round_cnt == 4'd9)
            col_out = col_in ^ col_key;
        else
            col_out = {b0, b1, b2, b3} ^ col_key;
    end

    logic [127:0] shifted_state;
    always_comb begin
        shifted_state = {
            state_reg[127:120], state_reg[87:80],
            state_reg[47:40],   state_reg[7:0],
            state_reg[95:88],   state_reg[55:48],
            state_reg[15:8],    state_reg[103:96],
            state_reg[63:56],   state_reg[23:16],
            state_reg[111:104], state_reg[71:64],
            state_reg[31:24],   state_reg[119:112],
            state_reg[79:72],   state_reg[39:32]
        };
    end

    logic [31:0] g_word, n0, n1, n2, n3;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            st          <= ST_IDLE;
            state_reg   <= 128'h0;
            round_key   <= 128'h0;
            subword_reg <= 32'h0;
            round_cnt   <= 4'h0;
            sub_cnt     <= 3'h0;
            col_cnt     <= 2'h0;
            rcon        <= 8'h01;
            out_valid        <= 1'b0;
        end else begin
            case (st)
                ST_IDLE: begin
                    out_valid <= 1'b0;
                    if (in_valid) begin
                        state_reg <= in_block ^ in_key;
                        round_key <= in_key;
                        round_cnt <= 4'd0;
                        rcon      <= 8'h01;
                        st        <= ST_KEY0;
                    end
                end

                ST_KEY0: begin
                    subword_reg[31:16] <= {sb0_out, sb1_out};
                    st <= ST_KEY1;
                end

                ST_KEY1: begin
                    subword_reg[15:0] <= {sb0_out, sb1_out};
                    st <= ST_KEY2;
                end

                ST_KEY2: begin
                    g_word = subword_reg ^ {rcon, 24'h000000};
                    n0 = round_key[127:96] ^ g_word;
                    n1 = round_key[95:64]  ^ n0;
                    n2 = round_key[63:32]  ^ n1;
                    n3 = round_key[31:0]   ^ n2;
                    round_key <= {n0, n1, n2, n3};
                    if (rcon == 8'h80)
                        rcon <= 8'h1b;
                    else if (rcon == 8'h1b)
                        rcon <= 8'h36;
                    else
                        rcon <= {rcon[6:0], 1'b0};
                    sub_cnt <= 3'd0;
                    st <= ST_SUB;
                end

                ST_SUB: begin
                    state_reg <= {state_reg[111:0], sb0_out, sb1_out};
                    if (sub_cnt == 3'd7) begin
                        sub_cnt <= 3'd0;
                        st <= ST_SHIFT;
                    end else begin
                        sub_cnt <= sub_cnt + 3'd1;
                    end
                end

                ST_SHIFT: begin
                    state_reg <= shifted_state;
                    col_cnt <= 2'd0;
                    st <= ST_COL;
                end

                ST_COL: begin
                    state_reg <= {state_reg[95:0], col_out};
                    if (col_cnt == 2'd3) begin
                        col_cnt <= 2'd0;
                        if (round_cnt == 4'd9) begin
                            out_valid <= 1'b1;
                            st <= ST_DONE;
                        end else begin
                            round_cnt <= round_cnt + 4'd1;
                            st <= ST_KEY0;
                        end
                    end else begin
                        col_cnt <= col_cnt + 2'd1;
                    end
                end

                ST_DONE: begin
                    if (out_ready) begin
                        out_valid <= 1'b0;
                        st <= ST_IDLE;
                    end
                end

                default: begin
                    st <= ST_IDLE;
                    out_valid <= 1'b0;
                end
            endcase
        end
    end

    // The single-slot starter implements only the forward cipher.
    assign in_ready = (st == ST_IDLE);
    assign out_block = state_reg;

endmodule
