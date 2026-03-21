# CLI (`fed` command)

`fed` is a command-line tool that opens files in FastEdit from the terminal.

## Setup

Add the following line to your shell configuration file (e.g., `~/.zshrc`):

```bash
export PATH="$PATH:/Applications/FastEdit.app/Contents/SharedSupport/bin"
```

Then reload your shell:

```bash
source ~/.zshrc
```

## Usage

```
fed [options] [file ...]
```

### Examples

```bash
# Open a file
fed myfile.txt

# Open multiple files
fed file1.txt file2.txt

# Launch FastEdit (new document)
fed
```

### Options

| Option | Description |
|---|---|
| `-h, --help` | Show help message |
| `-v, --version` | Show version |

## How it works

`fed` uses the macOS `open` command to launch FastEdit. When run from within the app bundle (`FastEdit.app/Contents/SharedSupport/bin/fed`), it automatically detects and uses that app. Otherwise, it falls back to `/Applications/FastEdit.app`.

## Future enhancements

- `--wait` — Wait until the file is closed
- `--line` / `--column` — Jump to a specific position
- stdin pipe support — Read text from pipe input
