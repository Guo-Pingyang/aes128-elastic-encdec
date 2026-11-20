module aes128 (
    input clk,
    input rst_n,
    input in_valid,
    input in_ready,
    input in_key,
    input in_block,
    input in_decrypt,
    output out_valid,
    output out_ready,
    output out_block
);
  // Add decryption logic here
  // Add overlap processing here
