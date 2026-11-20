# Extend a compact AES-128 core for backpressured traffic

The starter encrypts single blocks and keeps its result in the working state
until the consumer takes it. Extend it to support decryption and overlap
processing with a stalled consumer. It must fit both the logic and storage
budgets after synthesis.

Edit `/app/aes128.sv`. Submit one self-contained SystemVerilog module named
`aes128`, using the exact ports in the starter. The verifier collects only
this file.

## Interface

- An input transfers on a rising edge with `rst_n && in_valid && in_ready`.
  Sample `in_key`, `in_block`, and `in_decrypt` at that edge. These signals
  may change after acceptance.
- Produce the FIPS 197 AES-128 cipher when `in_decrypt=0`, or the inverse
  cipher when `in_decrypt=1`. In all 128-bit ports byte 0 is the most
  significant byte. State byte `4*column + row` occupies that position in the
  column-major state. The starter contains the forward S-box table and key
  expansion logic. The inverse S-box is the inverse permutation of that table.
- An output transfers on a rising edge with `rst_n && out_valid && out_ready`.
  Deliver exactly one result per accepted input in input order. Once a result
  is valid, keep `out_valid=1` and the result stable until it transfers.
  A result with no older output ahead of it must become valid even if
  `out_ready=0`. `out_block` is unspecified while `out_valid=0`.
- Reset is synchronous and active-low. A reset edge takes precedence over both
  handshakes, cancels every accepted request and queued result, and leaves
  `in_ready=1, out_valid=0`. Changing only `rst_n` between rising edges
  has no immediate effect on the interface.

## Cycle limits

Accept an input on the first edge with `in_valid=1` when the core is empty.
For an isolated request with no older result ahead of it, count from its
accepting edge to the edge after which its result first has `out_valid=1`.
The count must be at least one and meet these upper bounds.

| Request | Maximum cycles |
| --- | ---: |
| Encryption | 160 |
| Decryption, including a key change | 190 |
| Second of two consecutive isolated decryptions under the same key | 155 |

The repeated-key bound applies when the first output transferred before the
second request was presented, and no reset or other request intervened.
The blocks may differ.

## Overlap requirement

When a first result is visible and stalled, accept a second request on the
first edge it is presented. The stalled first result must stay stable.
When the sink subsequently releases that first result at least 190 cycles
after the second request was accepted, the release edge must be able to
retire the first result and accept a third request together. Present the
second result immediately after that edge, without an invalid cycle. The
direction and key of each request may differ.

## Synthesis limits

Both the RTL and the mapped netlist must pass the same tests. Use positive-edge
flip-flops clocked directly by `clk` and combinational logic. The module must
fit **5,100 generic cells**, including at most **720 flip-flops**. The count
comes from the flattened `aes128` JSON netlist after `read_verilog -sv`,
`synth -flatten -top aes128` with default ABC mapping, and `check -assert`,
using Yosys 0.33.

Use a single module with no preprocessor directives, latches, black boxes,
simulation-only blocks, file access, or testbench references. The source
limit is 256 KiB. You may choose any architecture that meets the behavior
and budgets.

In `/app`, run `./check.sh rtl` or `./check.sh gate` for public encryption,
cold decryption, and repeated-key smoke cases. `./check.sh area` reports the
mapped cell and flip-flop counts. The verifier also checks mixed directions,
arbitrary blocks and keys, stalls, overlap, and reset.
