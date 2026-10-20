#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS builds require macOS and Xcode. Run this script on a Mac." >&2
  exit 1
fi

project_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_directory"
command -v flutter >/dev/null || { echo "Install Flutter 3.47.6 or a compatible newer SDK." >&2; exit 1; }
xcrun --find xcodebuild >/dev/null

# Only foreground location is used to fill delivery addresses. The plugin's
# Swift Package manifest reads this while resolving/building native dependencies.
export BYPASS_PERMISSION_LOCATION_ALWAYS=1
live_define="--dart-define=SKP_MIDDLEWARE_BASE_URL=https://shri-middleware.ekarigar.com"
mode="${1:-check}"
flutter pub get

case "$mode" in
  check)
    flutter doctor -v
    /usr/bin/plutil -lint ios/Runner/Info.plist ios/Runner/Runner.entitlements
    flutter analyze
    flutter test
    ;;
  simulator)
    flutter build ios --simulator --debug "$live_define"
    ;;
  run)
    if [[ -z "${2:-}" ]]; then
      echo "Usage: bash scripts/ios_live.sh run <iPhone-or-simulator-device-id>" >&2
      flutter devices
      exit 1
    fi
    flutter run -d "$2" "$live_define"
    ;;
  ipa)
    # Select the Apple Team in Xcode first. Never commit certificates or profiles.
    flutter build ipa --release "$live_define"
    ;;
  *)
    echo "Usage: bash scripts/ios_live.sh {check|simulator|run <device-id>|ipa}" >&2
    exit 1
    ;;
esac
