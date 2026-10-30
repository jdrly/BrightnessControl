#!/bin/zsh
# Build BrightnessControl.app into build/, signed with a Developer ID under the
# hardened runtime, notarized and stapled, then install it to /Applications.
# ./scripts/build.sh. SIGN_IDENTITY picks the Developer ID Application identity
# (else the first); NOTARY_PROFILE the notarytool keychain profile (default
# swgl-notary). NOTARIZE=0 skips notarization, INSTALL=0 the install. Without a
# Developer ID it signs ad hoc and skips notarization, for a build on this Mac.
set -eu
root=${0:A:h:h}
cd $root
identity=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning |
  grep '"Developer ID Application' | grep -v CSSMERR | head -1 | awk '{print $2}')}
if [[ -z $identity ]]; then
  echo "no Developer ID Application identity, signing ad hoc without notarization" >&2
  identity=-
  NOTARIZE=0
fi
profile=${NOTARY_PROFILE:-swgl-notary}

swift build -c release --arch arm64
bin=$(swift build -c release --arch arm64 --show-bin-path)

app=build/BrightnessControl.app
rm -rf $app
mkdir -p $app/Contents/MacOS $app/Contents/Resources
cp $bin/BrightnessControl $app/Contents/MacOS/
cp Resources/Info.plist $app/Contents/

# The icon: Icon Composer's document, which macOS 26 and later draw as Liquid
# Glass (Assets.car), plus the .icns actool makes from it.
icon=$(mktemp -d)
xcrun actool Resources/AppIcon.icon --compile $icon --platform macosx \
  --minimum-deployment-target 27.0 --app-icon AppIcon \
  --output-partial-info-plist $icon/partial.plist >/dev/null
cp $icon/Assets.car $icon/AppIcon.icns $app/Contents/Resources/
rm -rf $icon

codesign --force --timestamp --options runtime --sign $identity $app
codesign --verify --strict --verbose=1 $app

if [[ ${NOTARIZE:-1} == 1 ]]; then
  zip=build/BrightnessControl.zip
  rm -f $zip
  ditto -c -k --keepParent $app $zip
  xcrun notarytool submit $zip --keychain-profile $profile --wait
  xcrun stapler staple $app
  xcrun stapler validate $app
  spctl --assess --type execute --verbose $app
  rm -f $zip
fi

if [[ ${INSTALL:-1} == 1 ]]; then
  pkill -x BrightnessControl || true
  rm -rf /Applications/BrightnessControl.app
  ditto $app /Applications/BrightnessControl.app
  open /Applications/BrightnessControl.app
  echo "installed /Applications/BrightnessControl.app"
fi
