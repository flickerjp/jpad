# JPad

MIDI pad controller for iOS / iPad (successor to the [JChord](https://github.com/flickerjp/jchord) codebase).

This repository was forked from JChord so JPad can evolve independently while JChord stays on its own track.

## Requirements

- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Sibling checkout of [tinytone](https://github.com/flickerjp/tinytone) at `../tinytone` (for `TinyToneCore`)

## Setup

```bash
cd /path/to/JPad
make project
open JPad.xcodeproj
```

Scheme: **JPad**

## Related repos

| Repo | Role |
|------|------|
| [jpad](https://github.com/flickerjp/jpad) (this) | JPad app |
| [jchord](https://github.com/flickerjp/jchord) | Original MIDI pad app (legacy line) |
| [tinytone](https://github.com/flickerjp/tinytone) | `TinyToneCore` synth package |

## App Store identity (unchanged from JChord)

- Bundle ID: `com.flickerproduct.jchord` (same App Store app)
- Build (`CURRENT_PROJECT_VERSION`): **155** — continue incrementing from JChord; do not reset
- Marketing version: `1.5.2`
- Pro subscription: `com.jflickeys.jchord.pro.yearly`

Preset file extensions (`.jchord`, `.jpd`, etc.) remain compatible.
