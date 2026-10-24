cmake_minimum_required(VERSION 3.16)

project(MySerial_Gemini VERSION 0.1 LANGUAGES CXX)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 确保找到所有必要的组件
find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml SerialPort QuickDialogs2 ShaderTools)

qt_standard_project_setup()

# 显式创建可执行程序
qt_add_executable(MySerial_Gemini
    main.cpp
    SerialManager.h SerialManager.cpp
    ChecksumHelper.h
    CommandStore.h
    SettingsStore.h
    RecordStore.h
    app_icon.rc
)

# 添加 QML 模块到该 target
qt_add_qml_module(MySerial_Gemini
    URI MySerial_Gemini
    VERSION 1.0
    QML_FILES Main.qml LiquidGlassSelection.qml
)

qt_add_shaders(MySerial_Gemini "liquid_glass_shaders"
    PREFIX "/shaders"
    BASE "shaders"
    FILES shaders/liquidglass.frag
)

# 链接库
target_link_libraries(MySerial_Gemini PRIVATE 
    Qt6::Core
    Qt6::Gui
    Qt6::Quick 
    Qt6::Qml 
    Qt6::SerialPort
    Qt6::QuickDialogs2
)

if(WIN32)
    target_link_libraries(MySerial_Gemini PRIVATE dwmapi user32)
endif()

set_target_properties(MySerial_Gemini PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

include(GNUInstallDirs)
install(TARGETS MySerial_Gemini
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# qt_finalize_executable(MySerial_Gemini) # 在使用 qt_add_qml_module 时通常不需要手动调用，或者由 Qt 自动处理
