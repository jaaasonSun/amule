# Filename Prefix Cleanup Design

## Goal

Add user-configurable filename prefix cleanup to the native Apple clients. The feature extends the existing filename encoding repair suggestion flow: when a configured prefix matches the start of a filename, the suggested rename removes that prefix.

## Behavior

- Users maintain a list of literal filename prefixes.
- Prefix matching is case-insensitive.
- Prefix matching is anchored to the beginning of the candidate filename.
- Prefix matching does not use regular expressions.
- Whitespace and punctuation are literal. A rule `ABCDED - ` matches `abcded - Movie.mkv`, but does not match `ABCDED- Movie.mkv`.
- When several rules match, the longest matching prefix wins.
- The generated suggestion trims leading and trailing whitespace after removing the prefix.
- Empty suggestions are discarded.
- Suggestions equal to the current filename are discarded.
- The app never renames automatically. It only feeds the existing "Use Suggested Filename" rename flow.

## Suggestion Pipeline

The final filename suggestion is produced by a shared policy:

1. Start with the daemon or bridge-provided filename suggestion if it is non-empty and differs from the current name.
2. Otherwise use the existing encoding repair suggestion for the current name.
3. Apply custom prefix cleanup to the candidate from step 1 or step 2.
4. If no encoding suggestion exists, apply custom prefix cleanup directly to the current name.
5. Return nil if the result is empty or unchanged from the current name.

This keeps existing mojibake, percent-encoding, and HTML entity repair behavior intact while allowing prefix-only cleanup for otherwise clean names.

## Architecture

The string transformation belongs in `SwiftEC/AMuleECClient` because `SharedModels` already depends on that package and both native clients consume `SharedModels`. UI layers should not duplicate prefix matching.

Shared model helpers expose the policy to UI:

- `DownloadItem.meaningfulFilenameSuggestion(prefixes:)`
- `DownloadAlternativeName.meaningfulFilenameSuggestion(prefixes:)`

Existing UI entry points continue to call `FilenameSuggestionPresentation.renameDraft` before opening or applying a rename draft.

## Preferences

Both native clients store prefixes under one `UserDefaults` key:

```text
amule.filenameCleanup.prefixes
```

The stored value is a JSON-encoded string array. Bad or missing JSON is treated as an empty prefix list. UI input filters empty strings and removes exact duplicate entries.

## UI

macOS adds a "Filename Cleanup" section to Preferences. iOS adds a "Filename Cleanup" section to Settings. Both sections allow adding and deleting literal prefixes.

Downloads lists, details views, context menus, and suggestion buttons use the shared suggestion policy with the configured prefixes.

## Testing

Core behavior is covered in `SwiftEC` unit tests for:

- case-insensitive prefix matching;
- longest-prefix precedence;
- literal whitespace and punctuation;
- empty-result filtering;
- encoding repair followed by prefix cleanup;
- prefix-only cleanup when there is no encoding repair.

Shared/UI tests verify that model helpers and rename draft presentation still suppress empty or unchanged suggestions.
