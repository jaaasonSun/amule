# Review Evidence: amulegui/macOS Backend Parity Implementation

Date: 2026-07-08

## Review Gate

`omo:review-work` was read for the post-implementation review gate. Its normal path requires spawning five subagents, but the available multi-agent tool policy in this session forbids spawning subagents unless the user explicitly requests subagents/delegation/parallel agent work. No subagent review was spawned.

## Local Review Findings

PASS with noted scope boundary.

- Goal fit: client-swap no longer advertises an incomplete Bridge/UI feature and the low-level builder now matches the daemon opcode/payload shape.
- Protocol correctness: `clientSwapToAnotherFile` is `0x54`; download-search remains `0x2A`; packet tags are `EC_TAG_CLIENT` integer plus `EC_TAG_PARTFILE` hash.
- Capability correctness: `client-swap-to-another-file` is in `unsupportedDisabledOperations` and absent from `allOperations`.
- Regression coverage: tests cover opcode/tag shape, default capability rejection, mixed `GET_UPDATE` parser semantics, and original search lifecycle response opcodes.
- Documentation: stale friends-opcode and client-swap alias claims no longer match the targeted documentation scan.
- Style consistency: integer ID clamping follows existing `ECOperations` patterns for ECID/category/server/friend IDs.

## Residual Scope

Broader amulegui parity gaps remain in parser depth and UI contracts:

- More `CLIENT_*`, `PARTFILE_*`, `KNOWNFILE_*`, and preference groups still need parser expansion.
- Friend shared files remain hidden until daemon and native UI behavior are explicitly designed.
- Client swap remains hidden until the Bridge/UI can select a concrete source client.

These are intentionally tracked as follow-up parity work rather than folded into this protocol/capability fix.
