#!/bin/zsh
# Publish a GitHub release: the notarized, stapled app zipped as
# build/BrightnessControl-<version>.zip, under the tag v<version> from
# Resources/Info.plist. ./scripts/release.sh. Needs a Developer ID and gh.
set -eu
root=${0:A:h:h}
cd $root
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
[[ -z $(git status --porcelain) ]] || { echo "commit your changes first" >&2; exit 1 }

INSTALL=0 ./scripts/build.sh
zip=build/BrightnessControl-$version.zip
rm -f $zip
ditto -c -k --keepParent build/BrightnessControl.app $zip

git tag -a v$version -m "BrightnessControl $version"
git push origin v$version
gh release create v$version $zip --title "BrightnessControl $version" --notes-file - <<EOF
Notarized by Apple. Unzip and move BrightnessControl.app to Applications. Needs macOS 27 on Apple silicon.

$(shasum -a 256 $zip | awk '{print "SHA-256: `" $1 "`"}')
EOF
