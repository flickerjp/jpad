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

## Bundle / Store IDs (JPad)

- Bundle ID: `com.flickerproduct.jpad`
- Pro subscription: `com.jflickeys.jpad.pro.yearly` (configure in App Store Connect)

Preset file extensions (`.jchord`, `.jpd`, etc.) remain compatible with JChord exports.
