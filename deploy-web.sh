#!/bin/sh
#
# Rebuilds the web version of Dokodoko Drills and deploys to samskivert.com

set -e

flutter build web --release --base-href /mrdriller/
rsync -av --delete build/web/ samskivert.com:/export/samskivert/pages/mrdriller/
