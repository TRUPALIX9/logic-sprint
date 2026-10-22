#!/usr/bin/env bash
# Renders every App Store creative option with headless Chrome into
# assets/brand/store/app_store/creative/:
#   header_<x>.html -> header_<x>_3840x1646.png   (product page header, 21:9)
#   search_<x>.html -> search_<x>_3840x2560.png   (search results, 3:2)
# Apple wants no alpha channel, so the PNGs are flattened to RGB.
set -euo pipefail
cd "$(dirname "$0")/../.."
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
out=assets/brand/store/app_store/creative
mkdir -p "$out"

for html in tool/creative/header_*.html tool/creative/search_*.html; do
  name=$(basename "$html" .html)
  [[ $name == header_* ]] && size=(3840 1646) || size=(3840 2560)
  png="$out/${name}_${size[0]}x${size[1]}.png"
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --virtual-time-budget=3000 \
    --window-size="${size[0]},${size[1]}" --screenshot="$PWD/$png" "file://$PWD/$html" 2>/dev/null
  python3 -c "from PIL import Image; import sys; Image.open(sys.argv[1]).convert('RGB').save(sys.argv[1])" "$png"
done
ls -1 "$out"
