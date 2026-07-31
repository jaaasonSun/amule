# 2026-07-08 — Download Details Sources Empty

## Bootstrap
- Tier: HEAVY. Reason: the user requested detailed full-chain verification across upstream amulegui, EC protocol/incremental updates, SwiftEC state, AppModel, and macOS details UI.
- Shape: delivery.
- Skills:
  - `omo:ulw-loop`: durable evidence, criteria, QA, checkpointing.
  - `omo:debugging`: hypothesis-driven RED->GREEN debugging.
  - `build-macos-apps:build-run-debug`: Swift/macOS build and surface verification.
  - `omo:ulw-plan`: consulted for plan rigor only; not using plan-only mode because user asked to continue the fix.
- Subagents: not spawned. Current `multi_agent_v1.spawn_agent` tool explicitly forbids spawning unless the user asks for subagents/parallel agents; this task asks for depth, not delegation.

## Exact User Symptom
After the previous fix, the download details page always shows "暂无可用来源". The same file in amulegui has multiple sources and shows username, version, filename, and other source fields.

## Hypotheses
1. Last fix over-tightened scoped source responses and drops selected-file sources when `EC_TAG_CLIENT_REQUEST_FILE` is omitted.
2. SwiftEC request shape differs from amulegui bottom source table and asks for the wrong data/update mode.
3. Native AppModel/UI keying loses sources between bridge cache and details view.

## Criteria
- C001 happy path: a scoped source response for selected download with amulegui-equivalent missing owner tags produces visible source rows with username/version/filename.
- C002 adversarial/regression: sparse global incremental client deltas still do not migrate sources from another download to the selected download.
- C003 real surface: macOS `DownloadDetailsWindowView` renders selected-download source rows instead of the empty-state text.

## Evidence Log
