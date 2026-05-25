# jcstore static site

Demo catalog at `web/jcstore/` for `https://flicker-jp.com/jcstore/` (**JPad** STORE).

## Files

| File | Role |
|------|------|
| `index.html` | Web カタログのトップ（人間向け UI） |
| `manifest.json` | アプリ／Web JS が読むカタログ index（機械可読） |
| `presets/*.json` | プリセット本体 |

## Local preview

```bash
cd web/jcstore
python3 -m http.server 8765
```

Open http://localhost:8765/ — Web MIDI preview works best in Chrome with a virtual or hardware synth.

## Sync preset JSON from app bundle

```bash
./scripts/sync-jcstore-presets.sh
```

Copies `JPad/PresetBundles/*.json` into `web/jcstore/presets/`, removes stale files, and regenerates:

- `JPad/Resources/jcstore-manifest.json`（アプリ同梱・オフライン STORE）
- `web/jcstore/manifest.json`（Web／リモート STORE）

`resourceName` はバンドル内の **ファイル名（拡張子なし）** に合わせる（例: `hard-rock-organ.json` → `hard-rock-organ`）。

## Deploy

Upload the entire `web/jcstore/` directory to the host so these URLs resolve:

- `https://flicker-jp.com/jcstore/manifest.json`
- `https://flicker-jp.com/jcstore/presets/{id}.json`
- `https://flicker-jp.com/jcstore/index.html`

The iOS app fetches the remote manifest first; preset files must stay on the `flicker-jp.com` `/jcstore/` path (whitelist).
