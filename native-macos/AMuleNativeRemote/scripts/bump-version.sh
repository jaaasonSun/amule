#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <version> [build-number]"
    echo "  version:     marketing version (e.g., 0.2.0)"
    echo "  build-number: optional build number (e.g., 2). Defaults to 1."
    exit 1
fi

VERSION="$1"
BUILD_NUMBER="${2:-1}"

echo "Bumping to version $VERSION (build $BUILD_NUMBER)"

ruby -e "
require 'xcodeproj'
project = Xcodeproj::Project.open('$ROOT_DIR/AMuleNativeRemote.xcodeproj')
project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['MARKETING_VERSION'] = '$VERSION'
    config.build_settings['CURRENT_PROJECT_VERSION'] = '$BUILD_NUMBER'
  end
end
project.save
puts 'Updated AMuleNativeRemote.xcodeproj'
"

ruby -e "
require 'xcodeproj'
project = Xcodeproj::Project.open('$ROOT_DIR/AMuleRemoteiOS.xcodeproj')
project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['MARKETING_VERSION'] = '$VERSION'
    config.build_settings['CURRENT_PROJECT_VERSION'] = '$BUILD_NUMBER'
  end
end
project.save
puts 'Updated AMuleRemoteiOS.xcodeproj'
"

sed -i '' "s/AMULE_APP_VERSION:-0.1.0/AMULE_APP_VERSION:-$VERSION/g" "$ROOT_DIR/scripts/build-app.sh"
echo "Updated scripts/build-app.sh"

echo ""
echo "Done. Version bumped to $VERSION (build $BUILD_NUMBER)"
echo "Next steps:"
echo "  1. Commit the changes"
echo "  2. Build and package: AMULE_APP_VERSION=$VERSION AMULE_BUILD_NUMBER=$BUILD_NUMBER ./scripts/build-app.sh"
echo "  3. Build iOS: AMULE_IOS_CODE_SIGNING_ALLOWED=NO ./scripts/build-ios-altstore.sh"
echo "  4. Create release: gh release create v$VERSION ..."
