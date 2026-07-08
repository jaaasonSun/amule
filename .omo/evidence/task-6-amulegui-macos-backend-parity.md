# Task 6 Evidence: Documentation Contract Alignment

Date: 2026-07-08

## Commands

```bash
rg -n 'friends opcode|clientSwapToAnotherFile / downloadSearchResult|0x2A.*clientSwap|Implementation Status: COMPLETE|Enable `FRIEND_SHARED`|Fix friends opcode' native-macos/AMuleNativeRemote/SwiftEC/Docs docs/superpowers/evidence
```

## Result

PASS. No stale documentation claims were found after updating:

- `native-macos/AMuleNativeRemote/SwiftEC/Docs/Operations.md`
- `native-macos/AMuleNativeRemote/SwiftEC/Docs/SwiftECV1Contract.md`
- `docs/superpowers/evidence/2026-07-07-feature-parity-report.md`

The docs now state:

- `client-swap-to-another-file` uses daemon opcode `0x54`, not `0x2A`.
- The builder requires `EC_TAG_CLIENT` plus `EC_TAG_PARTFILE`.
- The operation is not advertised until Bridge/UI source-client selection exists.
- Friends retrieval intentionally uses mixed `GET_UPDATE` semantics.
