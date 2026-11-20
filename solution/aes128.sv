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
        case (x)
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
            default: sbox = 8'h00;
        endcase
    endfunction

    localparam logic [2:0] IDLE    = 3'd0;
    localparam logic [2:0] KEY_HI  = 3'd1;
    localparam logic [2:0] KEY_LO  = 3'd2;
    localparam logic [2:0] SUB     = 3'd3;
    localparam logic [2:0] SHIFT   = 3'd4;
    localparam logic [2:0] COLUMN  = 3'd5;
    localparam logic [2:0] PUBLISH = 3'd6;

    logic [2:0] phase;
    logic [127:0] state_reg, round_key;
    logic [127:0] cached_key, cached_last_round_key;
    logic cache_valid, decrypt_q, expanding_q;
    logic [3:0] round_index;
    logic [2:0] slice_index;
    logic [15:0] subword_hi;
    logic [7:0] rcon;

    wire output_slot = !out_valid || out_ready;
    wire publish = (phase == PUBLISH) && output_slot;
    assign in_ready = (phase == IDLE) || publish;
    wire accept = in_valid && in_ready;
    wire cache_hit = cache_valid && (in_key == cached_key);
    wire use_cache = in_decrypt && cache_hit;
    wire [127:0] initial_key = use_cache ? cached_last_round_key : in_key;

    function automatic logic [7:0] xtime(input logic [7:0] x);
        xtime = {x[6:0], 1'b0} ^ (x[7] ? 8'h1b : 8'h00);
    endfunction

    function automatic logic [7:0] inverse_xtime(input logic [7:0] x);
        inverse_xtime = {1'b0, x[7:1]} ^ (x[0] ? 8'h8d : 8'h00);
    endfunction

    function automatic logic [7:0] inverse_affine(input logic [7:0] x);
        inverse_affine = {x[6:0], x[7]} ^ {x[4:0], x[7:5]} ^
                         {x[1:0], x[7:2]} ^ 8'h05;
    endfunction

    // Both directions share the same two forward S-box tables.
    // Inverse SubBytes applies the inverse affine map before and after a lookup.
    wire reverse_key = decrypt_q && !expanding_q;
    wire inverse_data = decrypt_q && (phase == SUB);
    wire [31:0] w0 = round_key[127:96];
    wire [31:0] w1 = round_key[95:64];
    wire [31:0] w2 = round_key[63:32];
    wire [31:0] w3 = round_key[31:0];
    wire [31:0] previous_last_word = w3 ^ w2;
    wire [31:0] subword_source = reverse_key ? previous_last_word : w3;

    logic [7:0] sb0_in, sb1_in;
    always_comb begin
        case (phase)
            KEY_HI: begin
                sb0_in = subword_source[23:16];
                sb1_in = subword_source[15:8];
            end
            KEY_LO: begin
                sb0_in = subword_source[7:0];
                sb1_in = subword_source[31:24];
            end
            default: begin
                sb0_in = inverse_data ? inverse_affine(state_reg[127:120]) : state_reg[127:120];
                sb1_in = inverse_data ? inverse_affine(state_reg[119:112]) : state_reg[119:112];
            end
        endcase
    end
    wire [7:0] sb0 = sbox(sb0_in);
    wire [7:0] sb1 = sbox(sb1_in);
    wire [7:0] next_byte0 = inverse_data ? inverse_affine(sb0) : sb0;
    wire [7:0] next_byte1 = inverse_data ? inverse_affine(sb1) : sb1;

    wire [31:0] schedule_g = {subword_hi, sb0, sb1} ^ {rcon, 24'b0};
    wire [31:0] next_w0 = w0 ^ schedule_g;
    wire [31:0] forward_w1 = w1 ^ next_w0;
    wire [31:0] forward_w2 = w2 ^ forward_w1;
    wire [31:0] forward_w3 = w3 ^ forward_w2;
    wire [127:0] updated_key = reverse_key
        ? {next_w0, w1 ^ w0, w2 ^ w1, previous_last_word}
        : {next_w0, forward_w1, forward_w2, forward_w3};

    wire [127:0] shifted_state;
    for (genvar col = 0; col < 4; col = col + 1) begin : shift_columns
        for (genvar row = 0; row < 4; row = row + 1) begin : shift_rows
            localparam integer DST = 127 - 8 * (4 * col + row);
            localparam integer FWD = 127 - 8 * (4 * ((col + row) % 4) + row);
            localparam integer REV = 127 - 8 * (4 * ((col + 4 - row) % 4) + row);
            assign shifted_state[DST -: 8] =
                decrypt_q ? state_reg[REV -: 8] : state_reg[FWD -: 8];
        end
    end

    logic [31:0] key_column;
    always_comb begin
        case (slice_index[1:0])
            2'd0: key_column = round_key[127:96];
            2'd1: key_column = round_key[95:64];
            2'd2: key_column = round_key[63:32];
            default: key_column = round_key[31:0];
        endcase
    end

    function automatic logic [31:0] mix_column(input logic [31:0] word);
        logic [7:0] a, b, c, d, total;
        begin
            {a, b, c, d} = word;
            total = a ^ b ^ c ^ d;
            mix_column = {
                a ^ total ^ xtime(a ^ b),
                b ^ total ^ xtime(b ^ c),
                c ^ total ^ xtime(c ^ d),
                d ^ total ^ xtime(d ^ a)
            };
        end
    endfunction

    wire [31:0] state_column = state_reg[127:96];
    wire [31:0] keyed_column = state_column ^ key_column;
    wire [31:0] mix_input = decrypt_q ? keyed_column : state_column;
    wire [7:0] inverse_u = decrypt_q
        ? xtime(xtime(mix_input[31:24] ^ mix_input[15:8])) : 8'b0;
    wire [7:0] inverse_v = decrypt_q
        ? xtime(xtime(mix_input[23:16] ^ mix_input[7:0])) : 8'b0;
    wire [31:0] mixed_column = mix_column(mix_input ^ {inverse_u, inverse_v, inverse_u, inverse_v});
    wire [31:0] next_column = (round_index == 4'd9)
        ? keyed_column : (mixed_column ^ (decrypt_q ? 32'b0 : key_column));

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            phase <= IDLE;
            out_valid <= 1'b0;
            cache_valid <= 1'b0;
        end else begin
            if (out_valid && out_ready)
                out_valid <= 1'b0;
            if (publish) begin
                out_block <= state_reg;
                out_valid <= 1'b1;
                phase <= IDLE;
            end

            if (accept) begin
                decrypt_q <= in_decrypt;
                expanding_q <= in_decrypt && !cache_hit;
                round_key <= initial_key;
                state_reg <= (in_decrypt && !cache_hit) ? in_block : (in_block ^ initial_key);
                round_index <= 4'd0;
                rcon <= use_cache ? 8'h36 : 8'h01;
                phase <= KEY_HI;
                if (in_decrypt && !cache_hit) begin
                    cached_key <= in_key;
                    cache_valid <= 1'b0;
                end
            end else begin
                case (phase)
                    KEY_HI: begin
                        subword_hi <= {sb0, sb1};
                        phase <= KEY_LO;
                    end
                    KEY_LO: begin
                        round_key <= updated_key;
                        rcon <= reverse_key ? inverse_xtime(rcon) : xtime(rcon);
                        if (expanding_q) begin
                            phase <= KEY_HI;
                            round_index <= round_index + 4'd1;
                            if (round_index == 4'd9) begin
                                expanding_q <= 1'b0;
                                cached_last_round_key <= updated_key;
                                cache_valid <= 1'b1;
                                state_reg <= state_reg ^ updated_key;
                                round_index <= 4'd0;
                                rcon <= 8'h36;
                            end
                        end else begin
                            slice_index <= 3'd0;
                            phase <= SUB;
                        end
                    end
                    SUB: begin
                        state_reg <= {state_reg[111:0], next_byte0, next_byte1};
                        slice_index <= slice_index + 3'd1;
                        if (slice_index == 3'd7)
                            phase <= SHIFT;
                    end
                    SHIFT: begin
                        state_reg <= shifted_state;
                        slice_index <= 3'd0;
                        phase <= COLUMN;
                    end
                    COLUMN: begin
                        state_reg <= {state_reg[95:0], next_column};
                        if (slice_index == 3'd3) begin
                            if (round_index == 4'd9) begin
                                phase <= PUBLISH;
                            end else begin
                                round_index <= round_index + 4'd1;
                                phase <= KEY_HI;
                            end
                        end else begin
                            slice_index <= slice_index + 3'd1;
                        end
                    end
                    default: begin
                    end
                endcase
            end
        end
    end
endmodule
