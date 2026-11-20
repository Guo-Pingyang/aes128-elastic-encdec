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
    reg [127:0] lut;
    begin
    case(x[7:4])
    4'h0: lut = 128'h7090b4ffdd7fb11e586ab4c6fc7d6eed;
    4'h1: lut = 128'hbf97c2fd6d9852b8193d3b484c53096c;
    4'h2: lut = 128'h2ec73cc25f7bf97720a287fb007dde67;
    4'h3: lut = 128'h5caa980af804c2b01090a1637baeb14e;
    4'h4: lut = 128'hac8225607aa40f58527dc4246f7a7a13;
    4'h5: lut = 128'h866af3ab0d784ce3ffa8a42897818acb;
    4'h6: lut = 128'hc28f1b3baa4e7a49ea2e69a24c5e4bfa;
    4'h7: lut = 128'he7bae4856bc2f7f1256823a8e61a68ab;
    4'h8: lut = 128'h0329b5599e08ecb46c1b3ffb86b4eab5;
    4'h9: lut = 128'h96cab30d0631bc48f6ac3b0cf334c006;
    4'ha: lut = 128'h7701cb91cc47b286849c64e00b2eb210;
    4'hb: lut = 128'h4cb33f6b7d8d2624e9da577d6a4510bd;
    4'hc: lut = 128'he3e11782256f2e53fb1b2efcd8a97a04;
    4'hd: lut = 128'hb84425590b4fce47c892d6ce94ea6f24;
    4'he: lut = 128'h9de7b8334813a3aedb76b6c09740ad39;
    4'hf: lut = 128'h523721e054b2f2104e9dac39c8704f1e;
    endcase
    sbox[0] = lut[0 + x[3:0]];
    sbox[1] = lut[16 + x[3:0]];
    sbox[2] = lut[32 + x[3:0]];
    sbox[3] = lut[48 + x[3:0]];
    sbox[4] = lut[64 + x[3:0]];
    sbox[5] = lut[80 + x[3:0]];
    sbox[6] = lut[96 + x[3:0]];
    sbox[7] = lut[112 + x[3:0]];
    end
    endfunction

    localparam IDLE=0, KEY0=1, KEY1=2, SUB=3, SHIFT=4, COL=5, DONE=6;
    reg [2:0] st;
    reg [127:0] state_reg, round_key, output_reg, cache_input, cache_last;
    reg cache_valid, decrypt, warmup;
    reg [15:0] subword;
    reg [3:0] round_cnt;
    reg [2:0] sub_cnt;
    reg [1:0] col_cnt;
    reg [7:0] rcon;
    function automatic [7:0] xtime(input [7:0] x);
        xtime = {x[6:0],1'b0} ^ (8'h1b & {8{x[7]}});
    endfunction
    function automatic [7:0] iaff(input [7:0] x);
        iaff = {x[6:0],x[7]} ^ {x[4:0],x[7:5]} ^ {x[1:0],x[7:2]} ^ 8'h05;
    endfunction
    wire [31:0] prior3 = round_key[31:0] ^ round_key[63:32];
    wire [31:0] key_source = (decrypt && !warmup) ? prior3 : round_key[31:0];
    wire [7:0] si0 = st == SUB ? state_reg[127:120] : (st == KEY0 ? key_source[23:16] : key_source[7:0]);
    wire [7:0] si1 = st == SUB ? state_reg[119:112] : (st == KEY0 ? key_source[15:8] : key_source[31:24]);
    wire inv = decrypt && st == SUB;
    wire [7:0] so0 = sbox(inv ? iaff(si0) : si0);
    wire [7:0] so1 = sbox(inv ? iaff(si1) : si1);
    wire [7:0] sb0 = inv ? iaff(so0) : so0;
    wire [7:0] sb1 = inv ? iaff(so1) : so1;
    wire [31:0] g = {subword, sb0, sb1} ^ {rcon,24'b0};
    wire [31:0] f0 = round_key[127:96] ^ g;
    wire [31:0] f1 = round_key[95:64] ^ f0;
    wire [31:0] f2 = round_key[63:32] ^ f1;
    wire [31:0] f3 = round_key[31:0] ^ f2;
    wire [127:0] nextkey = (decrypt && !warmup) ?
        {round_key[127:96]^g, round_key[127:96]^round_key[95:64],
         round_key[95:64]^round_key[63:32], prior3} : {f0,f1,f2,f3};
    wire [127:0] shift_f = {
        state_reg[127:120],state_reg[87:80],state_reg[47:40],state_reg[7:0],
        state_reg[95:88],state_reg[55:48],state_reg[15:8],state_reg[103:96],
        state_reg[63:56],state_reg[23:16],state_reg[111:104],state_reg[71:64],
        state_reg[31:24],state_reg[119:112],state_reg[79:72],state_reg[39:32]};
    wire [127:0] shift_i = {
        state_reg[127:120],state_reg[23:16],state_reg[47:40],state_reg[71:64],
        state_reg[95:88],state_reg[119:112],state_reg[15:8],state_reg[39:32],
        state_reg[63:56],state_reg[87:80],state_reg[111:104],state_reg[7:0],
        state_reg[31:24],state_reg[55:48],state_reg[79:72],state_reg[103:96]};
    wire [31:0] ck = col_cnt == 0 ? round_key[127:96] : col_cnt == 1 ? round_key[95:64] : col_cnt == 2 ? round_key[63:32] : round_key[31:0];
    wire [31:0] ci = state_reg[127:96] ^ (decrypt ? ck : 32'b0);
    wire [7:0] a = ci[31:24], b = ci[23:16], c = ci[15:8], d = ci[7:0];
    wire [7:0] u = decrypt ? xtime(xtime(a^c)) : 8'b0;
    wire [7:0] v = decrypt ? xtime(xtime(b^d)) : 8'b0;
    wire [7:0] aa=a^u, bb=b^v, cc=c^u, dd=d^v;
    wire [7:0] t=aa^bb^cc^dd;
    wire [31:0] mixed={aa^t^xtime(aa^bb),bb^t^xtime(bb^cc),cc^t^xtime(cc^dd),dd^t^xtime(dd^aa)};
    wire [31:0] co = (round_cnt == 9 ? ci : mixed) ^ (decrypt ? 32'b0 : ck);
    assign in_ready = st == IDLE || (st == DONE && (!out_valid || out_ready));
    assign out_block = output_reg;
    always @(posedge clk) begin
        if (!rst_n) begin
            st <= IDLE; out_valid <= 0; cache_valid <= 0;
        end else begin
            if (out_valid && out_ready) out_valid <= 0;
            if (st == DONE && (!out_valid || out_ready)) begin
                output_reg <= state_reg; out_valid <= 1; st <= IDLE;
            end
            if (in_valid && in_ready) begin
                state_reg <= in_block ^ (in_decrypt ? ((cache_valid && in_key == cache_input) ? cache_last : 128'b0) : in_key);
                decrypt <= in_decrypt; round_cnt <= 0; sub_cnt <= 0; col_cnt <= 0;
                if (in_decrypt && cache_valid && in_key == cache_input) begin
                    round_key <= cache_last;
                    rcon <= 8'h36; warmup <= 0; st <= SHIFT;
                end else begin
                    cache_input <= in_key; cache_valid <= 0;
                    round_key <= in_key; rcon <= 1;
                    warmup <= in_decrypt;
                    
                    st <= KEY0;
                end
            end else case (st)
                KEY0: begin subword <= {sb0,sb1}; st <= KEY1; end
                KEY1: begin
                    round_key <= nextkey;
                    if (decrypt && !warmup) begin
                        rcon <= (rcon == 8'h1b) ? 8'h80 : (rcon == 8'h36 ? 8'h1b : {1'b0,rcon[7:1]});
                        col_cnt <= 0; st <= COL;
                    end else begin
                        rcon <= xtime(rcon);
                        if (warmup) begin
                            if (round_cnt == 9) begin
                                cache_last <= nextkey; cache_valid <= 1;
                                state_reg <= state_reg ^ nextkey; warmup <= 0;
                                rcon <= 8'h36; round_cnt <= 0; st <= SHIFT;
                            end else begin round_cnt <= round_cnt + 1; st <= KEY0; end
                        end else begin
                            if (round_cnt == 9) begin cache_last <= nextkey; cache_valid <= 1; end
                            sub_cnt <= 0; st <= SUB;
                        end
                    end
                end
                SUB: begin
                    state_reg <= {state_reg[111:0],sb0,sb1};
                    if (sub_cnt == 7) begin sub_cnt <= 0; st <= decrypt ? KEY0 : SHIFT; end
                    else sub_cnt <= sub_cnt + 1;
                end
                SHIFT: begin state_reg <= decrypt ? shift_i : shift_f; if (decrypt) begin sub_cnt <= 0; st <= SUB; end else begin col_cnt <= 0; st <= COL; end end
                COL: begin
                    state_reg <= {state_reg[95:0],co};
                    if (col_cnt == 3) begin
                        col_cnt <= 0;
                        if (round_cnt == 9) st <= DONE;
                        else begin round_cnt <= round_cnt + 1; st <= decrypt ? SHIFT : KEY0; end
                    end else col_cnt <= col_cnt + 1;
                end
                default: begin end
            endcase
        end
    end
endmodule
