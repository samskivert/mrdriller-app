#!/bin/sh
#
# Builds the iOS version of Dokodoko Drills and uploads it to App Store Connect for TestFlight.
#
# ios/ExportOptions.plist tells Xcode to upload the build instead of exporting an ipa. The upload
# uses the Apple account signed in to Xcode (Settings -> Accounts), which needs App Manager or
# Admin on the team.
#
# The build number is the number of commits on HEAD, so it goes up with every commit. Pass a number
# to use that instead (say, to upload a second build of the same commit).
#
# The version comes from pubspec.yaml, which Flutter requires to be major.minor.patch, but a zero
# patch is dropped from the version users see: 1.1.0 ships as 1.1 (and 1.1.1 as 1.1.1).

set -e

VERSION=$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml | sed 's/\.0$//')
BUILD_NUMBER=${1:-$(git rev-list --count HEAD)}

flutter build ipa --release --build-name="$VERSION" --build-number="$BUILD_NUMBER" \
    --export-options-plist=ios/ExportOptions.plist
