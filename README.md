# Status Bar Extension (Single Entry)

A minimal macOS status bar application with a simple command-line interface (CLI) for displaying a single entry with customizable text and color in your menu bar.

## Features

- ✅ Single status bar item
- ✅ Custom text and color (hex code)
- ✅ 1px border, 4px corner radius, 4px padding
- ✅ Menu with "Quit" option
- ✅ Easy CLI control: add, remove, and quit from the terminal

## Project Structure

```
statusbar/
├── src/
│   └── main.swift         # Swift source code
├── bin/
│   ├── statusbar          # CLI script
│   └── statusbar-bin      # Compiled Swift binary (after build)
├── build.sh               # Build script
├── README.md
├── LICENSE
```

## Quick Start

### 1. Build the Application

```bash
chmod +x build.sh
./build.sh
```

### 2. Usage

Start the status bar app:
```bash
bin/statusbar start
```

Add or update the entry:
```bash
bin/statusbar add "Hello World" "#FF0000"
```

Remove the entry:
```bash
bin/statusbar remove
```

Quit the app:
```bash
bin/statusbar quit
```

If you call the CLI incorrectly, it will print helpful usage instructions.

### 3. (Optional) Install Globally

Copy the CLI script and binary to a directory in your `$PATH` (e.g., `/usr/local/bin/`):

```bash
cp bin/statusbar /usr/local/bin/
cp bin/statusbar-bin /usr/local/bin/
chmod +x /usr/local/bin/statusbar
```

Now you can use `statusbar` from anywhere:
```bash
statusbar start
statusbar add "Text" "#HEXCODE"
statusbar remove
statusbar quit
```

## Homebrew Installation

```bash
brew tap nikitamuravitski/statusbar
brew install statusbar
```
```

But as of now, your README is fully aligned with your current project structure and usage!

If you make further changes to your tap or formula, you may want to add or update the Homebrew section as needed. Let me know if you want me to add this snippet or make any other tweaks!

## Styling
- 1px border
- 4px corner radius
- 4px padding
- Text color and border color match the hex code you provide

## Menu
Clicking the status bar entry shows a menu with a "Quit" option.

## Requirements
- macOS 10.14 or later
- Swift compiler (included with Xcode Command Line Tools)

## Troubleshooting
- Ensure you have Xcode Command Line Tools installed
- Make sure the app is built (`./build.sh`)
- If the status bar item does not appear, make sure the app is running (`statusbar start`)
- If you get "Pipe ... does not exist", make sure the app is running
- If you move the CLI script or binary, ensure the script points to the correct binary location

## License
MIT License. See [LICENSE](LICENSE) for details. 