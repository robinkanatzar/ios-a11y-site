#!/usr/bin/env bash
# Rebuild downloads/ios-dynamic-type.zip from skill/ios-dynamic-type. Run before every commit that changes the skill.
set -euo pipefail
cd "$(dirname "$0")/skill"
rm -f ../downloads/ios-dynamic-type.zip
zip -rq -X ../downloads/ios-dynamic-type.zip ios-dynamic-type -x '*.DS_Store'
echo "Built downloads/ios-dynamic-type.zip"
