# MySerial_Gemini

A Qt 6-based C++ application designed to be a serial port assistant with potential Gemini AI integration.

## Project Overview

- **Technologies**: C++17, Qt 6 (Widgets), CMake.
- **Goal**: Provide a user interface for serial port communication, likely enhanced with AI capabilities (as suggested by the project name).
- **Architecture**: Standard Qt MainWindow-based GUI architecture.

## Project Structure

- `CMakeLists.txt`: Build configuration for Qt 6.
- `main.cpp`: Entry point for the application.
- `mainwindow.h` / `mainwindow.cpp`: Implementation of the main user interface.
- `mainwindow.ui`: Qt Designer file for the main window layout.
- `.qtcreator/`: Local IDE configuration files.

## Building and Running

### Prerequisites

- Qt 6 SDK (specifically the Widgets module).
- CMake 3.16+.
- A C++17 compatible compiler (e.g., MSVC, MinGW, Clang).

### Build Commands (via CLI)

```bash
# Generate build files
cmake -B build -G "Ninja"

# Build the project
cmake --build build

# Run the project
./build/MySerial_Gemini.exe
```

*Note: You can also open the `CMakeLists.txt` directly in IDEs like Qt Creator or VS Code with the CMake extension.*

## Development Conventions

- **Qt Standards**:
  - Use `AUTOMOC`, `AUTOUIC`, and `AUTORCC` for processing Qt meta-objects and UI files.
  - Follow the Signal/Slot pattern for inter-component communication.
- **Code Style**: Standard C++ with Qt naming conventions (CamelCase for classes, lowerCamelCase for members/functions).
- **TODOs**:
  - Add `SerialPort` component to `CMakeLists.txt` (e.g., `find_package(Qt6 REQUIRED COMPONENTS SerialPort)`).
  - Implement serial port detection and communication logic in `MainWindow`.
  - Design the UI in `mainwindow.ui`.
