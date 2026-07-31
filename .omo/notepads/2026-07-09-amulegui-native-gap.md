# amulegui vs native Apple client gap scan

Session: `.omo/ulw-loop/amulegui-native-gap-20260709`

Brief: systematically compare upstream `amulegui` / wxWidgets remote GUI and EC backend implementation with `native-macos/AMuleNativeRemote` + `SwiftEC`, then report feature gaps and backend implementation gaps. No product code changes, no commit.

Skills:
- `omo:ulw-loop`: explicit `ulw` request; evidence-bound research session.
- Native field guide: needed to map native macOS/iOS and SwiftEC layers.

Tier:
- HEAVY research-shape. The scan crosses upstream C++ GUI, C++ EC protocol/backend, SwiftUI app surfaces, AppModel bridge calls, and SwiftEC operation/parser implementation.
- Subagents not used because current `multi_agent_v1.spawn_agent` policy requires the user to explicitly ask for subagents.

Success criteria:
- C001: upstream amulegui feature/backend map captured in `.omo/evidence/amulegui-native-gap-20260709/upstream-map.txt`.
- C002: native client feature/backend map captured in `.omo/evidence/amulegui-native-gap-20260709/native-map.txt`.
- C003: prioritized source-cited gap report captured in `.omo/evidence/amulegui-native-gap-20260709/gap-report.md`.

Plan:
1. Extract upstream amulegui windows/actions and EC operations from `src/`.
2. Extract native windows/actions and SwiftEC supported operations/parsers.
3. Compare page-by-page and operation-by-operation.
4. Write a prioritized gap report with confidence, evidence, and implementation order.
