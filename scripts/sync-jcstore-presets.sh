#!/usr/bin/env bash
# Copies PresetBundles → web/jcstore/presets and regenerates jcstore manifests.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/JPad/PresetBundles"
DST="$ROOT/web/jcstore/presets"
UPDATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
PUBLISHED_AT="$(date -u +"%Y-%m-%d")"

mkdir -p "$DST"

# Remove presets no longer in PresetBundles.
for existing in "$DST"/*.json; do
  [[ -f "$existing" ]] || continue
  base="$(basename "$existing")"
  if [[ ! -f "$SRC/$base" ]]; then
    rm -f "$existing"
    echo "Removed stale $base"
  fi
done

count=0
for file in "$SRC"/*.json; do
  [[ -f "$file" ]] || continue
  cp "$file" "$DST/$(basename "$file")"
  count=$((count + 1))
done

export ROOT UPDATED_AT PUBLISHED_AT
python3 << 'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT"])
src = root / "JPad/PresetBundles"
updated_at = os.environ["UPDATED_AT"]
published_at = os.environ["PUBLISHED_AT"]

presets = []
for path in sorted(src.glob("*.json")):
    data = json.loads(path.read_text(encoding="utf-8"))
    resource_name = path.stem
    preset_id = data.get("id") or resource_name
    title = data.get("setName") or preset_id
    description = (data.get("description") or "").strip() or None
    presets.append({
        "id": preset_id,
        "title": title,
        "description": description,
        "publishedAt": published_at,
        "path": f"presets/{path.name}",
        "resourceName": resource_name,
    })

manifest = {
    "version": 1,
    "updatedAt": updated_at,
    "baseURL": "https://flicker-jp.com/jcstore/",
    "presets": presets,
}

app_manifest = root / "JPad/Resources/jcstore-manifest.json"
web_manifest = root / "web/jcstore/manifest.json"
app_manifest.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

web = json.loads(json.dumps(manifest))
for entry in web["presets"]:
    entry.pop("resourceName", None)
web_manifest.write_text(json.dumps(web, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

print(f"Manifest: {len(presets)} preset(s)")
for p in presets:
    print(f"  - {p['id']} ← {p['resourceName']}.json")
PY

echo "Synced $count preset(s) to $DST"
