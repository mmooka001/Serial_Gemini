# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MySerial_Gemini** is a Qt 6-based C++ serial port communication assistant with a modern QML UI. It provides serial port communication, command management, data recording, and encoding/decoding capabilities.

## Building and Running

### Prerequisites

- Qt 6 SDK (Core, Gui, Quick, Qml, SerialPort, QuickDialogs2 modules)
- CMake 3.16+
- C++17 compatible compiler (MinGW on Windows)

### Build Commands

```bash
# Generate build files
cmake -B build -G "MinGW Makefiles"

# Build the project
cmake --build build

# Run the application
./build/MySerial_Gemini.exe
```

### Alternative: Use Qt Creator

Open `CMakeLists.txt` directly in Qt Creator and build/run from the IDE.

## Architecture

### High-Level Structure

The application follows a **Qt Model-View pattern with C++ backend and QML frontend**:

```
C++ Backend (Business Logic)     QML Frontend (UI)
├── SerialManager.h/cpp         ├── Main.qml (Main window)
├── CommandStore.h              ├── TitleBar & Navigation
├── SettingsStore.h             ├── TerminalPanel (message display)
├── ChecksumHelper.h            ├── CommandPanel (command groups)
├── RecordStore.h               └── SendPanel (input & controls)
```

### Core Components

**SerialManager** (`SerialManager.h/cpp`)
- Manages serial port connections (open/close/read/write)
- Properties: `isOpen`, `currentPort`, `baudRate`, `lineEndingMode`
- Q_INVOKABLE methods: `availablePorts()`, `openPort()`, `closePort()`, `sendData()`, `sendDataWithChecksum()`
- Signals: `dataReceived()`, `errorOccurred()`, `isOpenChanged()`
- Handles Windows-specific window frame management (Aero Snap support)

**CommandStore** (`CommandStore.h`)
- Manages grouped commands (commands organized in named groups)
- Persists to `commands.json` in AppData location
- Supports CRUD operations for groups and commands
- Each command has: name, payload, isHex flag
- Supports import/export to JSON files

**SettingsStore** (`SettingsStore.h`)
- Manages application settings using QSettings
- Persists to QSettings standard location
- Settings: lineEndingMode, dataEncoding, hasDecimalMode, configPanelWidth, featurePanelWidth

**ChecksumHelper** (`ChecksumHelper.h`)
- Static utility class for checksum calculation
- Types: None, BCC (XOR), Sum8, CRC16_Modbus
- Registered as uncreatable QML type: `com.gemini.serial.Checksum`

**RecordStore** (`RecordStore.h`)
- Manages message history (RX/TX records)
- Auto-trims to 10000 records
- Supports CSV export
- Tracks RX/TX byte counters

## Main QML Structure

**Main.qml** (2266 lines) - Main application window

Key properties and features:
- Frameless window with custom title bar
- Dark/light theme support (isDark property)
- Color scheme: dark theme default (#1e1f22 bg, #2b2d30 card)
- Minimum size: 700x550
- Responsive layout: `isNarrow` (< 1100px), `isUltraNarrow` (< 900px)
- Two pages: "主控制台" (0), "系统信息" (1)
- Send history with up/down navigation (max 50 items)
- Auto-send timer (repeatable)
- Loop send functionality with sequential command execution

Main UI sections:
1. **TitleBar** (42px height)
   - Page tabs (主控制台/系统信息)
   - Window drag area
   - Pin (置顶) button
   - Theme toggle button
   - Minimize/Maximize/Close buttons

2. **ConfigPanel** (260px width, right margin 15px)
   - Port selection with tooltip (shows description + manufacturer)
   - Baud rate, data bits, stop bits, parity, flow control
   - Line ending mode selector
   - Connect/Disconnect button

3. **TerminalPanel** (flexible width)
   - Message display with color coding (TX=blue, RX=green, other=gray)
   - Display mode: ASCII / HEX / Both
   - Auto-scroll toggle
   - Copy button on hover
   - Timestamps

4. **SendPanel** (bottom area)
   - Input field with global HEX/TXT toggle
   - Checksum selector
   - Send button
   - Clear button

5. **CommandPanel** (300px width, shown when activePanel=0)
   - Grouped commands with add/delete
   - Each command: name, payload, HEX/TXT toggle
   - Send button per command
   - Loop send for selected commands

6. **StatusBar** (bottom)
   - Connection status
   - RX/TX byte counters
   - Current port info

## Key Implementation Details

### Data Flow

1. **Receiving Data**:
   ```
   SerialPort → SerialManager::readData() → emit dataReceived()
   → RecordStore::onDataReceived() → update records
   ```

2. **Sending Data**:
   ```
   UI button click → doSend() → SerialManager::sendData()
   → QSerialPort::write() → emit dataReceived(isSent=true)
   → RecordStore::onDataReceived() → update records
   ```

3. **Checksum Calculation**:
   - `ChecksumHelper::calculate()` - static method
   - Appended before line ending
   - Preview shown in send panel: `checksumValue` property

### Serial Port Configuration

The `openPort()` method in `SerialManager` accepts:
- `portName`: Serial port name
- `baudRate`: Baud rate (integer)
- `dataBits`: 5, 6, 7, or 8 (default: 8)
- `stopBits`: 1, 2, or 3 (default: 1)
- `parity`: 0=None, 1=Odd, 2=Even, 3=Mark, 4=Space
- `flowControl`: 0=None, 1=Hardware, 2=Software

### Windows-Specific Features

- Custom window frame with Aero Snap support
- DWM shadow enabled via `DwmExtendFrameIntoClientArea()`
- Always-on-top functionality via `SetWindowPos()`
- Frameless window with custom minimize/maximize/close buttons

### Persistence

All data persists to `QStandardPaths::AppDataLocation`:
- `commands.json`: Command groups and commands
- `quickinputs.json`: Quick input items
- `QSettings`: Application settings

### Responsive Layout

- `centerWidth = width - 260 - (featurePanelWidth + 50 + 8 if active) - 46`
- Feature panel (300px) slides in from right
- Terminal panel shrinks to accommodate feature panel
- Minimum widths enforced to prevent layout breakage

## Development Conventions

### C++ Standards

- C++17 required
- Qt naming conventions: CamelCase classes, lowerCamelCase members/functions
- Qt macros: `Q_OBJECT`, `Q_PROPERTY`, `Q_INVOKABLE`
- Signal/slot pattern for event handling
- Parent-child ownership for Qt objects (no manual memory management)

### QML Standards

- JavaScript functions for logic (avoid heavy C++ bindings)
- Use properties for reactive updates
- Follow QtQuick Controls 2 styling
- Custom styling via `background:` property overrides

### Code Style

- No emojis in source code
- Chinese comments and UI text acceptable
- Clean code: remove unused variables and dead code
- Avoid backwards-compatibility shims

## Common Tasks

### Adding a New Serial Port Property

1. Add `Q_PROPERTY` in `SerialManager.h`
2. Update `openPort()` in `SerialManager.cpp`
3. Expose via QML binding in `Main.qml`

### Adding a New Command Store Feature

1. Modify `CommandStore.h` - add Q_INVOKABLE method
2. Update `save()`/`load()` for JSON persistence
3. Add QML UI controls in `Main.qml`

### Modifying UI Colors

Update color properties in `Main.qml`:
- Dark theme: lines 24-34
- Light theme: same properties with different values

## Git Workflow

- **Main branch**: `main`
- **Feature branches**: `feature/` prefix
- **Commit style**: Chinese descriptions, semantic prefixes (feat/fix/refactor)
- **Recent focus**: UI redesign on `feature/ui-redesign` branch

## Testing

No formal test suite. Manual testing:
- Build and run application
- Test serial port open/close
- Test send/receive with real hardware
- Verify data encoding and checksum
- Test command saving/loading
- Test responsive layout at different window sizes
