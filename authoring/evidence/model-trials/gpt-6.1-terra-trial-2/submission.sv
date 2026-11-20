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
        sbox[0] = ((x[7:6] == 2'd0) & ((64'hb14ede67096c6eed >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd1) & ((64'h68ab4bfa8acb7a13 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd2) & ((64'h10bdb210c006eab5 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd3) & ((64'h4f1ead396f247a04 >> x[5:0]) & 1'b1));
        sbox[1] = ((x[7:6] == 2'd0) & ((64'h7bae007d4c53fc7d >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd1) & ((64'he61a4c5e97816f7a >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd2) & ((64'h6a450b2ef33486b4 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd3) & ((64'hc870974094ead8a9 >> x[5:0]) & 1'b1));
        sbox[2] = ((x[7:6] == 2'd0) & ((64'ha16387fb3b48b4c6 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd1) & ((64'h23a869a2a428c424 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd2) & ((64'h577d64e03b0c3ffb >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd3) & ((64'hac39b6c0d6ce2efc >> x[5:0]) & 1'b1));
        sbox[3] = ((x[7:6] == 2'd0) & ((64'h109020a2193d586a >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd1) & ((64'h2568ea2effa8527d >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd2) & ((64'he9da849cf6ac6c1b >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd3) & ((64'h4e9ddb76c892fb1b >> x[5:0]) & 1'b1));
        sbox[4] = ((x[7:6] == 2'd0) & ((64'hc2b0f97752b8b11e >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd1) & ((64'hf7f17a494ce30f58 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd2) & ((64'h2624b286bc48ecb4 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd3) & ((64'hf210a3aece472e53 >> x[5:0]) & 1'b1));
        sbox[5] = ((x[7:6] == 2'd0) & ((64'hf8045f7b6d98dd7f >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd1) & ((64'h6bc2aa4e0d787aa4 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd2) & ((64'h7d8dcc4706319e08 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd3) & ((64'h54b248130b4f256f >> x[5:0]) & 1'b1));
        sbox[6] = ((x[7:6] == 2'd0) & ((64'h980a3cc2c2fdb4ff >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd1) & ((64'he4851b3bf3ab2560 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd2) & ((64'h3f6bcb91b30db559 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd3) & ((64'h21e0b83325591782 >> x[5:0]) & 1'b1));
        sbox[7] = ((x[7:6] == 2'd0) & ((64'h5caa2ec7bf977090 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd1) & ((64'he7bac28f866aac82 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd2) & ((64'h4cb3770196ca0329 >> x[5:0]) & 1'b1)) | ((x[7:6] == 2'd3) & ((64'h52379de7b844e3e1 >> x[5:0]) & 1'b1));
    end
    endfunction

    function automatic [7:0] xtime(input [7:0] x);
        xtime = {x[6:0],1'b0} ^ (x[7] ? 8'h1b : 8'h00);
    endfunction
    function automatic [7:0] ia(input [7:0] x);
        ia = {x[6:0],x[7]} ^ {x[4:0],x[7:5]} ^ {x[1:0],x[7:2]} ^ 8'h05;
    endfunction

    localparam IDLE=0, KEY0=1, KEY1=2, KEY2=3, SUB=4, SHIFT=5, COL=6, DONE=7;
    logic [2:0] st;
    logic [127:0] state_reg, round_key, cache_key, cache_final;
    logic cache_valid, dec, precompute;
    logic [31:0] subword;
    logic [3:0] round_cnt;
    logic [2:0] sub_cnt;
    logic [1:0] col_cnt;
    logic [7:0] rcon;
    logic [7:0] si0, si1, so0, so1;
    logic [31:0] prevlast;
    assign prevlast = round_key[31:0] ^ round_key[63:32];
    always_comb begin
        si0=0; si1=0;
        if (st==KEY0) begin
            if (dec && !precompute) begin si0=prevlast[23:16]; si1=prevlast[15:8]; end
            else begin si0=round_key[23:16]; si1=round_key[15:8]; end
        end else if (st==KEY1) begin
            if (dec && !precompute) begin si0=prevlast[7:0]; si1=prevlast[31:24]; end
            else begin si0=round_key[7:0]; si1=round_key[31:24]; end
        end else if (st==SUB) begin
            si0=state_reg[127:120]; si1=state_reg[119:112];
        end
        
    end
    wire [7:0] sb0=sbox((st==SUB && dec) ? ia(si0) : si0), sb1=sbox((st==SUB && dec) ? ia(si1) : si1);
    always_comb begin
        so0=sb0; so1=sb1;
        if (st==SUB && dec) begin so0=ia(sb0); so1=ia(sb1); end
    end
    wire [31:0] g = subword ^ {rcon,24'b0};
    wire [31:0] f0=round_key[127:96]^g;
    wire [31:0] f1=round_key[95:64]^f0;
    wire [31:0] f2=round_key[63:32]^f1;
    wire [31:0] f3=round_key[31:0]^f2;
    wire [127:0] forward_key={f0,f1,f2,f3};
    wire [127:0] reverse_key={round_key[127:96]^g, round_key[127:96]^round_key[95:64], round_key[95:64]^round_key[63:32], prevlast};
    wire [127:0] shift_f={state_reg[127:120],state_reg[87:80],state_reg[47:40],state_reg[7:0],state_reg[95:88],state_reg[55:48],state_reg[15:8],state_reg[103:96],state_reg[63:56],state_reg[23:16],state_reg[111:104],state_reg[71:64],state_reg[31:24],state_reg[119:112],state_reg[79:72],state_reg[39:32]};
    wire [127:0] shift_i={state_reg[127:120],state_reg[23:16],state_reg[47:40],state_reg[71:64],state_reg[95:88],state_reg[119:112],state_reg[15:8],state_reg[39:32],state_reg[63:56],state_reg[87:80],state_reg[111:104],state_reg[7:0],state_reg[31:24],state_reg[55:48],state_reg[79:72],state_reg[103:96]};
    logic [31:0] ck, ci, co;
    logic [7:0] a,b,c,d,t,u,v,aa,bb,cc,dd;
    always_comb begin
        case (col_cnt)
            0: ck=round_key[127:96]; 1: ck=round_key[95:64];
            2: ck=round_key[63:32]; default: ck=round_key[31:0];
        endcase
        ci=state_reg[127:96] ^ (dec ? ck : 32'b0);
        {aa,bb,cc,dd}=ci;
        u=xtime(xtime(aa^cc)); v=xtime(xtime(bb^dd));
        a=aa ^ ((dec && round_cnt!=0) ? u : 0); b=bb ^ ((dec && round_cnt!=0) ? v : 0); c=cc ^ ((dec && round_cnt!=0) ? u : 0); d=dd ^ ((dec && round_cnt!=0) ? v : 0);
        t=a^b^c^d;
        if ((!dec && round_cnt==9) || (dec && round_cnt==0)) co=ci;
        else co={a^t^xtime(a^b),b^t^xtime(b^c),c^t^xtime(c^d),d^t^xtime(d^a)};
        if (!dec) co=co^ck;
    end
    assign in_ready=(st==IDLE) || (st==DONE && out_ready);
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            st<=IDLE; out_valid<=0; cache_valid<=0;
        end else begin
            if (out_valid && out_ready) out_valid<=0;
            case (st)
                IDLE: begin end
                KEY0: begin subword[31:16]<={so0,so1}; st<=KEY1; end
                KEY1: begin subword[15:0]<={so0,so1}; st<=KEY2; end
                KEY2: begin
                    if (dec && !precompute) begin
                        round_key<=reverse_key;
                        rcon <= {1'b0,rcon[7:1]} ^ (rcon[0] ? 8'h8d : 8'h00);
                        state_reg<=shift_i; sub_cnt<=0; st<=SUB;
                    end else begin
                        round_key<=forward_key; rcon<=xtime(rcon);
                        if (precompute) begin
                            if (round_cnt==9) begin
                                cache_final<=forward_key; cache_valid<=1;
                                state_reg<=state_reg^forward_key;
                                precompute<=0; round_cnt<=9; rcon<=8'h36; st<=KEY0;
                            end else begin round_cnt<=round_cnt+1'b1; st<=KEY0; end
                        end else begin sub_cnt<=0; st<=SUB; end
                    end
                end
                SUB: begin
                    state_reg<={state_reg[111:0],so0,so1};
                    if (sub_cnt==7) begin sub_cnt<=0; if(dec) begin col_cnt<=0; st<=COL; end else st<=SHIFT; end
                    else sub_cnt<=sub_cnt+1'b1;
                end
                SHIFT: begin state_reg<=shift_f; col_cnt<=0; st<=COL; end
                COL: begin
                    state_reg<={state_reg[95:0],co};
                    if (col_cnt==3) begin
                        col_cnt<=0;
                        if ((!dec && round_cnt==9) || (dec && round_cnt==0)) begin
                            if (!out_valid || out_ready) begin out_block<={state_reg[95:0],co}; out_valid<=1; st<=IDLE; end
                            else st<=DONE;
                        end else begin
                            if (dec) round_cnt<=round_cnt-1'b1; else round_cnt<=round_cnt+1'b1;
                            st<=KEY0;
                        end
                    end else col_cnt<=col_cnt+1'b1;
                end
                DONE: if (out_ready) begin out_block<=state_reg; out_valid<=1; st<=IDLE; end
                default: st<=IDLE;
            endcase
            if (in_valid && in_ready) begin
                dec<=in_decrypt; st<=KEY0; sub_cnt<=0; col_cnt<=0;
                if (in_decrypt) begin
                    if (cache_valid && cache_key==in_key) begin
                        state_reg<=in_block^cache_final; round_key<=cache_final;
                        precompute<=0; round_cnt<=9; rcon<=8'h36;
                    end else begin
                        state_reg<=in_block; round_key<=in_key; cache_key<=in_key;
                        cache_valid<=0; precompute<=1; round_cnt<=0; rcon<=1;
                    end
                end else begin
                    state_reg<=in_block^in_key; round_key<=in_key;
                    precompute<=0; round_cnt<=0; rcon<=1;
                end
            end
        end
    end
endmodule
