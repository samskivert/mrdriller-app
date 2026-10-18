#!/bin/sh
#
# Rebuilds the web version of Dokodoko Drills and deploys to samskivert.com

set -e

# A zero patch is dropped from the version users see, as in appstore-publish.sh.
VERSION=$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml | sed 's/\.0$//')

flutter build web --release --base-href /mrdriller/ --build-name="$VERSION"
rsync -av --delete build/web/ samskivert.com:/export/samskivert/pages/mrdriller/
