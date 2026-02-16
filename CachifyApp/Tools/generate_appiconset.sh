#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/source-1024.png [appiconset_dir]"
  exit 1
fi

SOURCE_IMAGE="$1"
APPICONSET_DIR="${2:-$(cd "$(dirname "$0")/.." && pwd)/App/Assets.xcassets/AppIcon.appiconset}"

if [[ ! -f "$SOURCE_IMAGE" ]]; then
  echo "Source image not found: $SOURCE_IMAGE"
  exit 1
fi

mkdir -p "$APPICONSET_DIR"

sizes=(
  "16 icon_16x16.png"
  "32 icon_16x16@2x.png"
  "32 icon_32x32.png"
  "64 icon_32x32@2x.png"
  "128 icon_128x128.png"
  "256 icon_128x128@2x.png"
  "256 icon_256x256.png"
  "512 icon_256x256@2x.png"
  "512 icon_512x512.png"
  "1024 icon_512x512@2x.png"
)

for entry in "${sizes[@]}"; do
  size="${entry%% *}"
  name="${entry##* }"
  out="$APPICONSET_DIR/$name"
  sips -z "$size" "$size" "$SOURCE_IMAGE" --out "$out" >/dev/null
  echo "Generated $name (${size}x${size})"
done

echo "App icon set generated at: $APPICONSET_DIR"
