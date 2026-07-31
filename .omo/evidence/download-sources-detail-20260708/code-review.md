Code review: approved.

Reviewed the source ownership changes against upstream amulegui semantics:
- sparse client deltas must not move an existing source to the currently selected download;
- parser request context is only trusted when at least one explicit matching request-file tag is present and no explicit mismatch exists;
- bridge source lists must come from the state store, not from a fallback parser path that can fabricate selected-download ownership.

No blocking issues remain in the scoped source-detail changes.
