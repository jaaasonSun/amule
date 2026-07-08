# Task 3 evidence - mixed GET_UPDATE semantics

Command:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter ECOperationsTests/testMixedGetUpdatePacketMergesDownloadsSourcesAndFriends --filter AMuleECBridgeAdapterTests/testSearchLifecycleAcceptsOriginalSuccessOpcodes
```

Result: passed.

Observed pass:

- `ECOperationsTests/testMixedGetUpdatePacketMergesDownloadsSourcesAndFriends`: passed.
- The same `EC_OP_SHARED_FILES` mixed update packet preserves a download, applies source-name deltas, applies source deltas, ignores a standalone known-file as a download, and parses friends.

Adversarial notes:

- Stale state: covered by seeding a baseline download before applying the mixed update.
- Misleading success output: assertions inspect parsed download/source/friend models, not just command exit.
