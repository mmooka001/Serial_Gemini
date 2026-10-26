cmake_minimum_required(VERSION 3.16)
project(theme_popup_interaction_qa LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml SerialPort QuickDialogs2 ShaderTools Test)
qt_standard_project_setup()
set(PROJECT_ROOT "${CMAKE_CURRENT_LIST_DIR}/../..")
set(APP_QML
    Main.qml AppTheme.qml ActionButton.qml CommandCard.qml CommandReorderController.qml
    TerminalMessageText.qml IntervalField.qml PanelDivider.qml SidebarResizeController.qml
    WindowDragArea.qml WindowStateController.qml SlimScrollBar.qml FocusDismissLayer.qml SendController.qml SegmentedControl.qml
    AccentColorPicker.qml LiquidGlassSelection.qml LiquidGlassToolbar.qml GlassComboBox.qml SerialLogo.qml PopupInputGuard.qml
)
set(QML_FILES)
foreach(name IN LISTS APP_QML)
    set(path "${PROJECT_ROOT}/${name}")
    set_source_files_properties("${path}" PROPERTIES QT_RESOURCE_ALIAS "${name}")
    list(APPEND QML_FILES "${path}")
endforeach()
add_executable(theme_popup_interaction_test
    ../../tests/theme_popup_interaction_test.cpp
    ../../SerialManager.cpp ../../SerialManager.h
    ../../ChecksumHelper.h ../../CommandStore.h ../../SettingsStore.h ../../RecordStore.h ../../PayloadCodec.h
)
qt_add_qml_module(theme_popup_interaction_test URI MySerial_Gemini VERSION 1.0 QML_FILES ${QML_FILES})
qt_add_shaders(theme_popup_interaction_test "liquid_glass_shaders"
    PREFIX "/shaders" BASE "${PROJECT_ROOT}/shaders" FILES "${PROJECT_ROOT}/shaders/liquidglass.frag")
target_include_directories(theme_popup_interaction_test PRIVATE "${PROJECT_ROOT}")
target_link_libraries(theme_popup_interaction_test PRIVATE
    Qt6::Core Qt6::Gui Qt6::Quick Qt6::Qml Qt6::SerialPort Qt6::QuickDialogs2 Qt6::ShaderTools Qt6::Test)
