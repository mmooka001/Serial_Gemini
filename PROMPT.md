# Serial Assistant Feature Port Plan
# Web (Vue) → Qt6/QML Migration

## Architecture Overview
The Qt project uses:
- C++ backend: SerialManager, CommandStore, ChecksumHelper (header-only)
- Single Main.qml for all UI
- CMakeLists.txt build system
- Qt 6.11, MinGW 64-bit, QML module system

## Current Source Files (root of E:\Workspace_QT\MySerial_Gemini)
- CMakeLists.txt
- main.cpp
- Main.qml
- SerialManager.h / SerialManager.cpp
- ChecksumHelper.h
- CommandStore.h
- app_icon.ico / app_icon.rc

## Target Architecture
Keep flat file structure. New C++ files to add:
- SettingsStore.h (header-only) - persistent settings
- QuickInputStore.h (header-only) - quick input presets
- RecordStore.h (header-only) - record/session management
- DataEncoder.h (header-only) - UTF-8/GBK encoding utilities

Modified files:
- SerialManager.h/.cpp - add data bits, parity, stop bits, flow control, reconnection
- CommandStore.h - extend with search, export
- Main.qml - complete rewrite with new layout

## Feature Implementation Details

### 1. SerialManager Enhancements (C++)
Current: openPort(portName, baudRate) only
Add:
- setConfig(baudRate, dataBits, parity, stopBits, flowControl)
- Data bits: QSerialPort::Data5..Data8
- Parity: None, Even, Odd, Mark, Space
- Stop bits: One, OnePointFive, Two
- Flow control: None, Hardware, Software
- Line ending append mode: None(0), LF(1), CR(2), CRLF(3), Custom(4)
- Line ending string property
- Reconnect method
- Auto-reconnect on settings change
- RX/TX byte counters (read-only properties)
- Clear counters method

### 2. SettingsStore (new, header-only)
Persistent QSettings-based:
- lineEndingMode (int: 0-4)
- customLineEnding (QString)
- dataEncoding (QString: "UTF-8" | "GBK")
- hasDecimalMode (bool)
- autoScrollEnabled (bool)
- theme (int: 0=dark, 1=light)
- windowGeometry (QByteArray)

### 3. QuickInputStore (new, header-only)
JSON-file based like CommandStore:
- items: list of {name, payload, isHex, delay, enabled, remark}
- add/remove/update/move methods
- import/export JSON
- send loop management (start/stop with timer)
- Default items: AT+RST, AT+GMR, etc.

### 4. RecordStore (new, header-only)
- records: list of {type, content, timestamp, displayMode}
- add(type, content, timestamp)
- clear()
- export JSON
- rxCount, txCount
- search(query) - simple string match

### 5. DataEncoder (new, header-only)
- UTF-8 ↔ QByteArray (default)
- GBK ↔ QByteArray (via QTextCodec)
- hexStringToBytes, bytesToHexString
- hexFormat (0x48, 0x65...)
- decFormat
- validateHexString

### 6. QML UI Layout (Main.qml rewrite)
Layout structure (matching web version):
```
+------+------------------------------------------+
| Act  | TopBar (title + window controls)         |
| ivi  +------------------------------------------+
| ty   |                                          |
| Bar  | TerminalPanel / RecordPanel              |
|      |                                          |
| (si |                                          |
| de) +------------------------------------------+
|      | ControlBar (mode toggles + checksum)     |
|      +------------------------------------------+
|      | SendPanel (textarea + send button)       |
+------+------------------------------------------+
| StatusBar (connection status + RX/TX counts)    |
+-------------------------------------------------+
```

Left sidebar (ActivityBar):
- Device settings toggle
- Quick input toggle
- Record history toggle
- ASCII table toggle
- Settings toggle

Right panel (context-dependent):
- DeviceSetting: serial config (port, baud, data bits, parity, stop, flow)
- QuickInput: quick input table with send/import/export
- RecordHistory: past sessions
- ASCII table: full 0-127 reference
- Settings: line ending, encoding, decimal mode

Main area:
- Top: Terminal/Record display (switchable)
- Middle: Control bar (RX/TX HEX/TXT toggles, timestamp, clear, export, search, auto-scroll)
- Bottom: Send panel (textarea, checksum selector, send button, auto-send toggle)

### 7. Keyboard Shortcuts
- Shift+Enter: Send
- Ctrl+F: Search
- Ctrl+S: Reformat hex
- Up/Down: History navigation (in send area)

### 8. Search
- Ctrl+F opens search overlay
- Filter records by text
- Scroll to matching record

### 9. ASCII Table Dialog
- Full 0-127 table
- Columns: DEC, HEX, BIN, CHAR, DESCRIPTION
- Control chars highlighted

### 10. Auto-Send
- Toggle button next to send
- Configurable interval (default 1000ms)
- Timer-based repeat of last sent data

### 11. Line Endings
- None, LF(\n), CR(\r), CRLF(\r\n), Custom
- Appended automatically in ASCII send mode

### 12. Encoding
- UTF-8 (default) / GBK switch
- Affects both display and send

## CMakeLists.txt Updates
- Add new .h files to sources
- Ensure Qt6::SerialPort linked
- QML_FILES: Main.qml
