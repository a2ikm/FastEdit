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

Open `FastEdit.xcodeproj` in Xcode and run (⌘R), or use Make:

```
make build      # Debug build
make release    # Release build
make install    # Release build + copy to /Applications
make uninstall  # Remove from /Applications
make clean      # Clean build artifacts
```

## License

[MIT](LICENSE)
