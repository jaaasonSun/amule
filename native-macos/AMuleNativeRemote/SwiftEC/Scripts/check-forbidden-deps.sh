#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

FORBIDDEN_PATTERN='(OpenSSL|openssl|Crypto\+\+|CryptoPP|cryptopp|wxWidgets|wxwidgets|wx_base|Boost|boost/)'
SCAN_PATHS=(
  "${PACKAGE_DIR}/Package.swift"
  "${PACKAGE_DIR}/Sources"
  "${PACKAGE_DIR}/Tests"
)

if ! command -v grep >/dev/null 2>&1; then
  echo "error: grep is required to scan SwiftEC dependencies" >&2
  exit 2
fi

matches=()
while IFS= read -r match; do
  matches+=("${match}")
done < <(
  grep \
    --recursive \
    --extended-regexp \
    --line-number \
    --binary-files=without-match \
    --exclude-dir=.build \
    --exclude-dir=.swiftpm \
    --exclude='*.xcodeproj' \
    "${FORBIDDEN_PATTERN}" \
    "${SCAN_PATHS[@]}" \
    2>/dev/null || true
)

if (( ${#matches[@]} > 0 )); then
  echo "error: SwiftEC must not depend on OpenSSL, Crypto++, wxWidgets, or Boost." >&2
  echo "Forbidden dependency references found:" >&2
  printf '%s\n' "${matches[@]}" >&2
  exit 1
fi

echo "SwiftEC forbidden dependency scan passed."
