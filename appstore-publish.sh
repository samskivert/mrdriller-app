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

set -e

BUILD_NUMBER=${1:-$(git rev-list --count HEAD)}

flutter build ipa --release --build-number="$BUILD_NUMBER" \
    --export-options-plist=ios/ExportOptions.plist
