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


    function automatic [7:0] sbox(input [7:0] x);
        begin
            case(x)
                8'h00: sbox = 8'h63;
                8'h01: sbox = 8'h7c;
                8'h02: sbox = 8'h77;
                8'h03: sbox = 8'h7b;
                8'h04: sbox = 8'hf2;
                8'h05: sbox = 8'h6b;
                8'h06: sbox = 8'h6f;
                8'h07: sbox = 8'hc5;
                8'h08: sbox = 8'h30;
                8'h09: sbox = 8'h01;
                8'h0a: sbox = 8'h67;
                8'h0b: sbox = 8'h2b;
                8'h0c: sbox = 8'hfe;
                8'h0d: sbox = 8'hd7;
                8'h0e: sbox = 8'hab;
                8'h0f: sbox = 8'h76;
                8'h10: sbox = 8'hca;
                8'h11: sbox = 8'h82;
                8'h12: sbox = 8'hc9;
                8'h13: sbox = 8'h7d;
                8'h14: sbox = 8'hfa;
                8'h15: sbox = 8'h59;
                8'h16: sbox = 8'h47;
                8'h17: sbox = 8'hf0;
                8'h18: sbox = 8'had;
                8'h19: sbox = 8'hd4;
                8'h1a: sbox = 8'ha2;
                8'h1b: sbox = 8'haf;
                8'h1c: sbox = 8'h9c;
                8'h1d: sbox = 8'ha4;
                8'h1e: sbox = 8'h72;
                8'h1f: sbox = 8'hc0;
                8'h20: sbox = 8'hb7;
                8'h21: sbox = 8'hfd;
                8'h22: sbox = 8'h93;
                8'h23: sbox = 8'h26;
                8'h24: sbox = 8'h36;
                8'h25: sbox = 8'h3f;
                8'h26: sbox = 8'hf7;
                8'h27: sbox = 8'hcc;
                8'h28: sbox = 8'h34;
                8'h29: sbox = 8'ha5;
                8'h2a: sbox = 8'he5;
                8'h2b: sbox = 8'hf1;
                8'h2c: sbox = 8'h71;
                8'h2d: sbox = 8'hd8;
                8'h2e: sbox = 8'h31;
                8'h2f: sbox = 8'h15;
                8'h30: sbox = 8'h04;
                8'h31: sbox = 8'hc7;
                8'h32: sbox = 8'h23;
                8'h33: sbox = 8'hc3;
                8'h34: sbox = 8'h18;
                8'h35: sbox = 8'h96;
                8'h36: sbox = 8'h05;
                8'h37: sbox = 8'h9a;
                8'h38: sbox = 8'h07;
                8'h39: sbox = 8'h12;
                8'h3a: sbox = 8'h80;
                8'h3b: sbox = 8'he2;
                8'h3c: sbox = 8'heb;
                8'h3d: sbox = 8'h27;
                8'h3e: sbox = 8'hb2;
                8'h3f: sbox = 8'h75;
                8'h40: sbox = 8'h09;
                8'h41: sbox = 8'h83;
                8'h42: sbox = 8'h2c;
                8'h43: sbox = 8'h1a;
                8'h44: sbox = 8'h1b;
                8'h45: sbox = 8'h6e;
                8'h46: sbox = 8'h5a;
                8'h47: sbox = 8'ha0;
                8'h48: sbox = 8'h52;
                8'h49: sbox = 8'h3b;
                8'h4a: sbox = 8'hd6;
                8'h4b: sbox = 8'hb3;
                8'h4c: sbox = 8'h29;
                8'h4d: sbox = 8'he3;
                8'h4e: sbox = 8'h2f;
                8'h4f: sbox = 8'h84;
                8'h50: sbox = 8'h53;
                8'h51: sbox = 8'hd1;
                8'h52: sbox = 8'h00;
                8'h53: sbox = 8'hed;
                8'h54: sbox = 8'h20;
                8'h55: sbox = 8'hfc;
                8'h56: sbox = 8'hb1;
                8'h57: sbox = 8'h5b;
                8'h58: sbox = 8'h6a;
                8'h59: sbox = 8'hcb;
                8'h5a: sbox = 8'hbe;
                8'h5b: sbox = 8'h39;
                8'h5c: sbox = 8'h4a;
                8'h5d: sbox = 8'h4c;
                8'h5e: sbox = 8'h58;
                8'h5f: sbox = 8'hcf;
                8'h60: sbox = 8'hd0;
                8'h61: sbox = 8'hef;
                8'h62: sbox = 8'haa;
                8'h63: sbox = 8'hfb;
                8'h64: sbox = 8'h43;
                8'h65: sbox = 8'h4d;
                8'h66: sbox = 8'h33;
                8'h67: sbox = 8'h85;
                8'h68: sbox = 8'h45;
                8'h69: sbox = 8'hf9;
                8'h6a: sbox = 8'h02;
                8'h6b: sbox = 8'h7f;
                8'h6c: sbox = 8'h50;
                8'h6d: sbox = 8'h3c;
                8'h6e: sbox = 8'h9f;
                8'h6f: sbox = 8'ha8;
                8'h70: sbox = 8'h51;
                8'h71: sbox = 8'ha3;
                8'h72: sbox = 8'h40;
                8'h73: sbox = 8'h8f;
                8'h74: sbox = 8'h92;
                8'h75: sbox = 8'h9d;
                8'h76: sbox = 8'h38;
                8'h77: sbox = 8'hf5;
                8'h78: sbox = 8'hbc;
                8'h79: sbox = 8'hb6;
                8'h7a: sbox = 8'hda;
                8'h7b: sbox = 8'h21;
                8'h7c: sbox = 8'h10;
                8'h7d: sbox = 8'hff;
                8'h7e: sbox = 8'hf3;
                8'h7f: sbox = 8'hd2;
                8'h80: sbox = 8'hcd;
                8'h81: sbox = 8'h0c;
                8'h82: sbox = 8'h13;
                8'h83: sbox = 8'hec;
                8'h84: sbox = 8'h5f;
                8'h85: sbox = 8'h97;
                8'h86: sbox = 8'h44;
                8'h87: sbox = 8'h17;
                8'h88: sbox = 8'hc4;
                8'h89: sbox = 8'ha7;
                8'h8a: sbox = 8'h7e;
                8'h8b: sbox = 8'h3d;
                8'h8c: sbox = 8'h64;
                8'h8d: sbox = 8'h5d;
                8'h8e: sbox = 8'h19;
                8'h8f: sbox = 8'h73;
                8'h90: sbox = 8'h60;
                8'h91: sbox = 8'h81;
                8'h92: sbox = 8'h4f;
                8'h93: sbox = 8'hdc;
                8'h94: sbox = 8'h22;
                8'h95: sbox = 8'h2a;
                8'h96: sbox = 8'h90;
                8'h97: sbox = 8'h88;
                8'h98: sbox = 8'h46;
                8'h99: sbox = 8'hee;
                8'h9a: sbox = 8'hb8;
                8'h9b: sbox = 8'h14;
                8'h9c: sbox = 8'hde;
                8'h9d: sbox = 8'h5e;
                8'h9e: sbox = 8'h0b;
                8'h9f: sbox = 8'hdb;
                8'ha0: sbox = 8'he0;
                8'ha1: sbox = 8'h32;
                8'ha2: sbox = 8'h3a;
                8'ha3: sbox = 8'h0a;
                8'ha4: sbox = 8'h49;
                8'ha5: sbox = 8'h06;
                8'ha6: sbox = 8'h24;
                8'ha7: sbox = 8'h5c;
                8'ha8: sbox = 8'hc2;
                8'ha9: sbox = 8'hd3;
                8'haa: sbox = 8'hac;
                8'hab: sbox = 8'h62;
                8'hac: sbox = 8'h91;
                8'had: sbox = 8'h95;
                8'hae: sbox = 8'he4;
                8'haf: sbox = 8'h79;
                8'hb0: sbox = 8'he7;
                8'hb1: sbox = 8'hc8;
                8'hb2: sbox = 8'h37;
                8'hb3: sbox = 8'h6d;
                8'hb4: sbox = 8'h8d;
                8'hb5: sbox = 8'hd5;
                8'hb6: sbox = 8'h4e;
                8'hb7: sbox = 8'ha9;
                8'hb8: sbox = 8'h6c;
                8'hb9: sbox = 8'h56;
                8'hba: sbox = 8'hf4;
                8'hbb: sbox = 8'hea;
                8'hbc: sbox = 8'h65;
                8'hbd: sbox = 8'h7a;
                8'hbe: sbox = 8'hae;
                8'hbf: sbox = 8'h08;
                8'hc0: sbox = 8'hba;
                8'hc1: sbox = 8'h78;
                8'hc2: sbox = 8'h25;
                8'hc3: sbox = 8'h2e;
                8'hc4: sbox = 8'h1c;
                8'hc5: sbox = 8'ha6;
                8'hc6: sbox = 8'hb4;
                8'hc7: sbox = 8'hc6;
                8'hc8: sbox = 8'he8;
                8'hc9: sbox = 8'hdd;
                8'hca: sbox = 8'h74;
                8'hcb: sbox = 8'h1f;
                8'hcc: sbox = 8'h4b;
                8'hcd: sbox = 8'hbd;
                8'hce: sbox = 8'h8b;
                8'hcf: sbox = 8'h8a;
                8'hd0: sbox = 8'h70;
                8'hd1: sbox = 8'h3e;
                8'hd2: sbox = 8'hb5;
                8'hd3: sbox = 8'h66;
                8'hd4: sbox = 8'h48;
                8'hd5: sbox = 8'h03;
                8'hd6: sbox = 8'hf6;
                8'hd7: sbox = 8'h0e;
                8'hd8: sbox = 8'h61;
                8'hd9: sbox = 8'h35;
                8'hda: sbox = 8'h57;
                8'hdb: sbox = 8'hb9;
                8'hdc: sbox = 8'h86;
                8'hdd: sbox = 8'hc1;
                8'hde: sbox = 8'h1d;
                8'hdf: sbox = 8'h9e;
                8'he0: sbox = 8'he1;
                8'he1: sbox = 8'hf8;
                8'he2: sbox = 8'h98;
                8'he3: sbox = 8'h11;
                8'he4: sbox = 8'h69;
                8'he5: sbox = 8'hd9;
                8'he6: sbox = 8'h8e;
                8'he7: sbox = 8'h94;
                8'he8: sbox = 8'h9b;
                8'he9: sbox = 8'h1e;
                8'hea: sbox = 8'h87;
                8'heb: sbox = 8'he9;
                8'hec: sbox = 8'hce;
                8'hed: sbox = 8'h55;
                8'hee: sbox = 8'h28;
                8'hef: sbox = 8'hdf;
                8'hf0: sbox = 8'h8c;
                8'hf1: sbox = 8'ha1;
                8'hf2: sbox = 8'h89;
                8'hf3: sbox = 8'h0d;
                8'hf4: sbox = 8'hbf;
                8'hf5: sbox = 8'he6;
                8'hf6: sbox = 8'h42;
                8'hf7: sbox = 8'h68;
                8'hf8: sbox = 8'h41;
                8'hf9: sbox = 8'h99;
                8'hfa: sbox = 8'h2d;
                8'hfb: sbox = 8'h0f;
                8'hfc: sbox = 8'hb0;
                8'hfd: sbox = 8'h54;
                8'hfe: sbox = 8'hbb;
                8'hff: sbox = 8'h16;
                default: sbox = 0;
            endcase
        end
    endfunction


    function automatic [7:0] xtime(input [7:0] x);
        xtime = {x[6:0],1'b0} ^ (x[7] ? 8'h1b : 8'h00);
    endfunction
    function automatic [7:0] ia(input [7:0] x);
        ia = {x[6:0],x[7]} ^ {x[4:0],x[7:5]} ^ {x[1:0],x[7:2]} ^ 8'h05;
    endfunction
    function automatic [127:0] shift_f(input [127:0] x);
        shift_f = {x[127:120],x[87:80],x[47:40],x[7:0],
                   x[95:88],x[55:48],x[15:8],x[103:96],
                   x[63:56],x[23:16],x[111:104],x[71:64],
                   x[31:24],x[119:112],x[79:72],x[39:32]};
    endfunction
    function automatic [127:0] shift_i(input [127:0] x);
        shift_i = {x[127:120],x[23:16],x[47:40],x[71:64],
                   x[95:88],x[119:112],x[15:8],x[39:32],
                   x[63:56],x[87:80],x[111:104],x[7:0],
                   x[31:24],x[55:48],x[79:72],x[103:96]};
    endfunction
    localparam IDLE=0, KEY0=1, KEY1=2, KEY2=3, SUB=4, COL=5, DONE=6;
    logic [2:0] st;
    logic [127:0] state_reg, round_key, cache_last, out_reg;
    logic cache_valid, dec, precompute;
    logic [31:0] subword;
    logic [3:0] round_cnt;
    logic [2:0] sub_cnt;
    logic [1:0] col_cnt;
    logic [7:0] rcon;
    wire [31:0] prev3 = round_key[31:0] ^ round_key[63:32];
    wire [31:0] key_source = (dec && !precompute) ? prev3 : round_key[31:0];
    wire [7:0] si0 = st == KEY0 ? key_source[23:16] : st == KEY1 ? key_source[7:0] : state_reg[127:120];
    wire [7:0] si1 = st == KEY0 ? key_source[15:8] : st == KEY1 ? key_source[31:24] : state_reg[119:112];
    wire inv = dec && st == SUB;
    wire [7:0] so0x = sbox(inv ? ia(si0) : si0);
    wire [7:0] so1x = sbox(inv ? ia(si1) : si1);
    wire [7:0] so0 = inv ? ia(so0x) : so0x;
    wire [7:0] so1 = inv ? ia(so1x) : so1x;
    wire [31:0] g = subword ^ {rcon,24'b0};
    wire [31:0] fw0 = round_key[127:96] ^ g;
    wire [31:0] fw1 = round_key[95:64] ^ fw0;
    wire [31:0] fw2 = round_key[63:32] ^ fw1;
    wire [31:0] fw3 = round_key[31:0] ^ fw2;
    wire [127:0] forward_key = {fw0,fw1,fw2,fw3};
    wire [127:0] reverse_key = {round_key[127:96] ^ g, round_key[95:64] ^ round_key[127:96], round_key[63:32] ^ round_key[95:64], prev3};
    wire [127:0] sub_state = {state_reg[111:0],so0,so1};
    wire [31:0] ck = col_cnt == 0 ? round_key[127:96] : col_cnt == 1 ? round_key[95:64] : col_cnt == 2 ? round_key[63:32] : round_key[31:0];
    wire [31:0] ci = state_reg[127:96] ^ (dec ? ck : 32'b0);
    wire [7:0] a0=ci[31:24], a1=ci[23:16], a2=ci[15:8], a3=ci[7:0];
    wire [7:0] u = dec ? xtime(xtime(a0 ^ a2)) : 8'b0;
    wire [7:0] v = dec ? xtime(xtime(a1 ^ a3)) : 8'b0;
    wire [7:0] c0=a0^u, c1=a1^v, c2=a2^u, c3=a3^v;
    wire [7:0] t=c0^c1^c2^c3;
    wire [31:0] mix = {c0^t^xtime(c0^c1),c1^t^xtime(c1^c2),c2^t^xtime(c2^c3),c3^t^xtime(c3^c0)};
    wire [31:0] co = (round_cnt == 9 ? ci : mix) ^ (dec ? 32'b0 : ck);
    wire [127:0] col_state = {state_reg[95:0],co};
    assign out_block=out_reg;
    assign in_ready = st == IDLE || (st == DONE && (!out_valid || out_ready));
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            st <= IDLE; out_valid <= 0; cache_valid <= 0;
        end else begin
            if (out_valid && out_ready) out_valid <= 0;
            if (st == DONE && (!out_valid || out_ready)) begin
                out_reg <= state_reg; out_valid <= 1; st <= IDLE;
            end
            if (in_ready && in_valid) begin
                dec <= in_decrypt;
                cache_valid <= 0;
                round_cnt <= 0;
                if (in_decrypt && cache_valid && in_key == round_key) begin
                    round_key <= cache_last;
                    state_reg <= shift_i(in_block ^ cache_last);
                    rcon <= 8'h36;
                    precompute <= 0;
                end else begin
                    round_key <= in_key;
                    state_reg <= in_decrypt ? in_block : in_block ^ in_key;
                    rcon <= 1;
                    precompute <= in_decrypt;
                    cache_valid <= 0;
                end
                st <= KEY0;
            end else case (st)
                KEY0: begin subword[31:16] <= {so0,so1}; st <= KEY1; end
                KEY1: begin subword[15:0] <= {so0,so1}; st <= KEY2; end
                KEY2: begin
                    if (dec && !precompute) begin
                        round_key <= reverse_key;
                        if (round_cnt == 9) cache_valid <= 1;
                        rcon <= {1'b0,rcon[7:1]} ^ (rcon[0] ? 8'h8d : 8'h00);
                    end else begin
                        round_key <= forward_key;
                        rcon <= xtime(rcon);
                    end
                    if (precompute) begin
                        if (round_cnt == 9) begin
                            cache_last <= forward_key;
                            state_reg <= shift_i(state_reg ^ forward_key);
                            precompute <= 0; round_cnt <= 0; rcon <= 8'h36;
                        end else round_cnt <= round_cnt + 1'b1;
                        st <= KEY0;
                    end else begin
                        sub_cnt <= 0; st <= SUB;
                    end
                end
                SUB: begin
                    if (sub_cnt == 7) begin
                        state_reg <= dec ? sub_state : shift_f(sub_state);
                        col_cnt <= 0; st <= COL;
                    end else begin state_reg <= sub_state; sub_cnt <= sub_cnt + 1'b1; end
                end
                COL: begin
                    if (col_cnt == 3) begin
                        if (round_cnt == 9) begin state_reg <= col_state; st <= DONE; end
                        else begin
                            state_reg <= dec ? shift_i(col_state) : col_state;
                            round_cnt <= round_cnt + 1'b1; st <= KEY0;
                        end
                    end else begin state_reg <= col_state; col_cnt <= col_cnt + 1'b1; end
                end
                default: begin end
            endcase
        end
    end
endmodule
