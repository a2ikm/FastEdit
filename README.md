# FastEdit

A lightweight plain text editor for macOS.

## Features

- Document-based: one file per window
- UTF-8 text editing with Osaka-Mono font
- Line wrap toggle (View > Wrap/Unwrap Lines)
- Font size controls (⌘+, ⌘-, ⌘0)
- Save confirmation on close
- Window position restored across sessions

## Command-Line Tool

Add FastEdit to your PATH to open files from the terminal:

```bash
# Add to ~/.zshrc
export PATH="$PATH:/Applications/FastEdit.app/Contents/SharedSupport/bin"
```

Then use `fed` to open files:

```bash
fed file.txt            # Open a file
fed file1.txt file2.txt # Open multiple files
fed                     # Launch FastEdit
```

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
make test       # Run unit tests
make clean      # Clean build artifacts
```

## License

The FastEdit source code is licensed under [CC0 1.0 Universal](LICENSE). Third-party libraries are subject to their own licenses.
