# AltStore Distribution

This note documents how to prepare the iOS/iPadOS app for AltStore-managed installs.

## Target Audience

The current setup targets AltStore Classic / AltStore World style distribution:

- build a standard `.ipa`;
- host that `.ipa` on HTTPS;
- host an AltStore source JSON that points at the `.ipa`.

AltStore PAL distribution is different: the source version `downloadURL` must point at a notarized ADP `manifest.json` or ADP root directory, and the app needs Apple's alternative marketplace distribution/notarization flow before publishing.

## Project Requirements

The iOS target must keep these values correct because AltStore validates them from the app bundle and the source metadata:

- `CFBundleIdentifier`: `org.amule.remote.ios`
- `CFBundleShortVersionString`: project `MARKETING_VERSION`
- `CFBundleVersion`: project `CURRENT_PROJECT_VERSION`
- `MinimumOSVersion`: project `IPHONEOS_DEPLOYMENT_TARGET`
- `CFBundleURLTypes`: registers `ed2k` and `magnet`
- `NSLocalNetworkUsageDescription`: explains LAN daemon access

The Xcode target uses `iOS/AMuleRemoteiOS/Info.plist` directly. Do not switch back to a generated Info.plist unless all custom URL scheme and privacy keys are also generated.

## Build Artifacts

From `native-macos/AMuleNativeRemote`:

```bash
./scripts/build-ios-altstore.sh
```

This creates:

- `dist/ios-altstore/AMuleRemoteiOS-<version>-<build>.ipa`
- `dist/ios-altstore/aMule.png`

To also generate `dist/ios-altstore/altstore-source.json`, provide the public HTTPS base URL where the IPA and icon will be hosted:

```bash
AMULE_ALTSTORE_BASE_URL="https://example.com/amule-ios" \
AMULE_ALTSTORE_ICON_URL="https://example.com/amule-ios/aMule.png" \
./scripts/build-ios-altstore.sh
```

If `AMULE_ALTSTORE_ICON_URL` is omitted, the script assumes `aMule.png` exists next to the IPA and source JSON under `AMULE_ALTSTORE_BASE_URL`.

Useful override environment variables:

- `AMULE_IOS_CONFIGURATION`: defaults to `Release`.
- `AMULE_IOS_DERIVED_DATA`: defaults to `/tmp/amule-ios-altstore-build`.
- `AMULE_ALTSTORE_DIST_DIR`: defaults to `dist/ios-altstore`.
- `AMULE_ALTSTORE_SOURCE_NAME`: source display name.
- `AMULE_ALTSTORE_SOURCE_ID`: stable source identifier.
- `AMULE_ALTSTORE_DEVELOPER_NAME`: app developer display name.
- `AMULE_ALTSTORE_VERSION_DESCRIPTION`: release note for the current version.

## Hosting And Updates

Host both files over HTTPS:

- `altstore-source.json`
- `AMuleRemoteiOS-<version>-<build>.ipa`

When publishing an update:

1. Increment `MARKETING_VERSION` or `CURRENT_PROJECT_VERSION` in `AMuleRemoteiOS.xcodeproj`.
2. Run `./scripts/build-ios-altstore.sh` with the same hosting base URL.
3. Upload the new IPA and source JSON.
4. Keep the newest compatible version first in the source `versions` array. AltStore treats the first compatible entry as latest.

The generated source includes `appPermissions.privacy.NSLocalNetworkUsageDescription` so AltStore can surface the LAN permission before install.

## GitHub Releases And Pages

The repository includes `.github/workflows/ios-altstore-release.yml` for GitHub-hosted distribution.

Recommended repository settings:

1. Enable GitHub Pages.
2. Set Pages source to `GitHub Actions`.
3. Make sure Actions can create releases: repository Settings -> Actions -> General -> Workflow permissions -> `Read and write permissions`.

Publish a release by pushing a tag:

```bash
git tag ios-v0.1.0
git push origin ios-v0.1.0
```

The workflow will:

1. Build an unsigned iPhoneOS Release app. This is intentional for AltStore Classic because AltServer/AltStore re-signs the IPA for the installing Apple ID.
2. Upload the IPA to the matching GitHub Release.
3. Publish `altstore-source.json` and `aMule.png` to GitHub Pages.

The AltStore source URL becomes:

```text
https://<owner>.github.io/<repo>/altstore-source.json
```

The generated source points its app `downloadURL` at the GitHub Release asset for that tag.

You can also start the workflow manually from GitHub Actions. Provide `release_tag`, for example `ios-v0.1.0`, and optional release notes.
