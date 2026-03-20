# FastEdit

A lightweight plain text editor for macOS.

## Features

- Document-based: one file per window
- UTF-8 text editing with Osaka-Mono font
- Line wrap toggle (View > Wrap/Unwrap Lines)
- Font size controls (⌘+, ⌘-, ⌘0)
- Save confirmation on close
- Window position restored across sessions

## Requirements

- macOS 26.2+
- Xcode 26.3+

## Build

Open `FastEdit.xcodeproj` in Xcode and run (⌘R), or build from the command line:

```
xcodebuild -scheme FastEdit -configuration Debug build
```

## License

[MIT](LICENSE)
