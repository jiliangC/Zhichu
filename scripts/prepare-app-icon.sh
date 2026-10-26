#!/bin/bash
# Convert the selected PNG to macOS app assets; preserve the approved artwork.
set -euo pipefail
cd "$(dirname "$0")/.."
SOURCE=Resources/Brand/ZhichuIcon.png
CATALOG=Resources/Assets.xcassets
SET="$CATALOG/AppIcon.appiconset"
ICONSET=Resources/Brand/AppIcon.iconset
mkdir -p "$SET" "$ICONSET"
for size in 16 32 128 256 512; do
  double=$((size * 2))
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
  sips -z "$double" "$double" "$SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
  cp "$ICONSET/icon_${size}x${size}.png" "$SET/"
  cp "$ICONSET/icon_${size}x${size}@2x.png" "$SET/"
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
python3 - <<'PY'
from pathlib import Path
import json
root=Path('Resources/Assets.xcassets')
info={'version':1,'author':'xcode'}
(root/'Contents.json').write_text(json.dumps({'info':info},indent=2))
images=[{'idiom':'mac','size':f'{n}x{n}','scale':scale,'filename':f'icon_{n}x{n}'+('@2x' if scale=='2x' else '')+'.png'} for n in [16,32,128,256,512] for scale in ['1x','2x']]
(root/'AppIcon.appiconset/Contents.json').write_text(json.dumps({'images':images,'info':info},indent=2))
PY
