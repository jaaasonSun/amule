# Task 1 evidence - SwiftEC client-swap parity

## RED proof

Command:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter ECOperationsTests/testMutatingOperationBuildersUseBridgeOpcodesAndTags --filter ECOperationsTests/testUnsupportedDisabledOperationNamesRemainUnadvertised --filter ECSupportedOpsTests/testAllOperationsMatchCanonicalFixture --filter ECSupportedOpsTests/testUnsupportedDisabledOperationsAreNotAdvertised
```

Result: failed before production changes.

Observed failures:

- `ECOperations.swapClientToAnotherFile(clientID:hash:)` does not exist.
- Existing implementation cannot build the upstream daemon request shape requiring `EC_TAG_CLIENT` plus `EC_TAG_PARTFILE`.

Relevant protocol evidence:

- `src/libs/ec/cpp/ECCodes.h`: `EC_OP_DOWNLOAD_SEARCH_RESULT = 0x2A`; `EC_OP_CLIENT_SWAP_TO_ANOTHER_FILE = 0x54`.
- `src/ExternalConn.cpp:1483-1493`: daemon dispatch reads `EC_TAG_CLIENT` and `EC_TAG_PARTFILE`.

## GREEN proof

Command:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter ECOperationsTests/testMutatingOperationBuildersUseBridgeOpcodesAndTags --filter ECOperationsTests/testUnsupportedDisabledOperationNamesRemainUnadvertised --filter ECSupportedOpsTests/testAllOperationsMatchCanonicalFixture --filter ECSupportedOpsTests/testUnsupportedDisabledOperationsAreNotAdvertised
```

Result: passed.

Observed pass:

- `ECSupportedOpsTests`: 2 tests, 0 failures.
- `ECOperationsTests`: 2 tests, 0 failures.
- `client-swap-to-another-file` is no longer in advertised capabilities.
- Low-level builder now uses opcode `0x54`, `EC_TAG_CLIENT`, and `EC_TAG_PARTFILE`.
