# Building and running

**English** · [Русский](BUILD.ru.md)

Two separate things live here: the Python tool (works everywhere) and the macOS app
(sources in `app/`).

## 1. The Python tool (all platforms)

Requirements: Python 3.9 or newer.

```bash
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install pyserial

python3 scripts/pr21.py read --out radio.img
```

Port selection:

| System | Port | Notes |
|---|---|---|
| macOS | `/dev/cu.usbserial*`, `/dev/cu.wchusbserial*` | CH340 driver is built into macOS 13+; do not install anything |
| Windows | `COM3`, `COM4`, … | CH340 driver usually installs itself; check Device Manager → Ports |
| Linux | `/dev/ttyUSB0` | add your user to the `dialout` group, then re-login |

Pass the port explicitly if auto-detection picks the wrong one:

```bash
python3 scripts/pr21.py read --port /dev/ttyUSB0 --out radio.img     # Linux
python3 scripts/pr21.py read --port COM3 --out radio.img             # Windows
```

No build step is needed: it is a single script. To make it executable as a command:

```bash
cp scripts/pr21.py /usr/local/bin/pr21 && chmod +x /usr/local/bin/pr21
```

## 2. The skill package

The skill is plain Markdown plus the script. To rebuild the distributable archive:

```bash
zip -qr radio-pr21-programmer.zip SKILL.md SKILL.ru.md README.md README.ru.md \
    BUILD.md BUILD.ru.md LICENSE references scripts assets examples
```

Install it into an agent's skill directory (for example `~/.dsh/skills/radio-pr21/`
or `~/.claude/skills/radio-pr21/`) by unpacking the archive there, or simply pass
`SKILL.md` and `references/` to the model together with the task.

## 3. The macOS application

Sources are in `app/`. The app is a prototype — see `app/README.md` for what works and what
does not.

```bash
cd app
./build.sh                 # Intel
ARCH=arm64 ./build.sh      # Apple Silicon
UNIVERSAL=1 ./build.sh     # both architectures (not tested)
open "build/PR-21 Manager.app"
```

The script compiles with the SDK from Command Line Tools, assembles the bundle and signs it
ad hoc. If you prefer to do it by hand, the same steps are:

Requirements:

- macOS 13 or newer;
- Xcode Command Line Tools (`xcode-select --install`) — a full Xcode installation is not needed;
- Swift 5.9+ (`swiftc --version`).

Build:

```bash
SDK="$(xcrun --show-sdk-path)"
swiftc -O -parse-as-library -sdk "$SDK" -target x86_64-apple-macos13.0 \
  -o "PR-21 Manager.app/Contents/MacOS/PR21Manager" \
  src/core/*.swift src/ui/*.swift src/main.swift
```

Assemble the bundle (`Info.plist` with `CFBundleIdentifier`, `CFBundleExecutable`,
`CFBundlePackageType=APPL`), then sign ad hoc:

```bash
codesign --force --deep --sign - "PR-21 Manager.app"
```

Notes:

- The protocol layer uses POSIX `termios` and therefore does not build on Windows;
  the Windows path is the Python tool.
- The app was built and tested on Intel macOS. An Apple Silicon build is possible with
  `-target arm64-apple-macos13.0` or as a universal binary, but it has not been tested.

## 4. Troubleshooting the build

| Symptom | Cause and fix |
|---|---|
| `'main' attribute cannot be used in a module that contains top-level code` | add `-parse-as-library` |
| `mapfile: command not found` | macOS ships bash 3.2; avoid bash 4 features or use `/opt/homebrew/bin/bash` |
| `swiftc: command not found` | install Xcode Command Line Tools |
| `serial.SerialException: could not open port` | the port is busy or the user lacks rights (Linux: `dialout`) |
| Radio does not answer | see `references/troubleshooting.md` |
