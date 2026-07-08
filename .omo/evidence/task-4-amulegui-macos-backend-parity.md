# Task 4 evidence - search lifecycle response opcodes

Command:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter ECOperationsTests/testMixedGetUpdatePacketMergesDownloadsSourcesAndFriends --filter AMuleECBridgeAdapterTests/testSearchLifecycleAcceptsOriginalSuccessOpcodes
```

Result: passed.

Observed pass:

- `AMuleECBridgeAdapterTests/testSearchLifecycleAcceptsOriginalSuccessOpcodes`: passed.
- Search start accepts daemon `EC_OP_STRINGS`, then polls `EC_OP_SEARCH_PROGRESS` and `EC_OP_SEARCH_RESULTS`.
- Sent opcode sequence was auth request/password followed by `0x26`, `0x29`, `0x28`.

Adversarial notes:

- Misleading success output: assertions inspect progress, result name, and sent opcodes.
- Flaky tests: poll interval is `0`, no sleep-dependent timing.
