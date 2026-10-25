cmake_minimum_required(VERSION 3.16)
project(serial_loopback_qa LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick SerialPort)
get_filename_component(APP_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
add_executable(serial_loopback_test
    ../serial_loopback_test.cpp
    "${APP_ROOT}/SerialManager.cpp"
    "${APP_ROOT}/SerialManager.h"
    "${APP_ROOT}/RecordStore.h"
)
target_include_directories(serial_loopback_test PRIVATE "${APP_ROOT}")
target_link_libraries(serial_loopback_test PRIVATE Qt6::Core Qt6::Gui Qt6::SerialPort)

add_executable(serial_qml_workflow_test
    ../serial_qml_workflow_test.cpp
    "${APP_ROOT}/SerialManager.cpp"
    "${APP_ROOT}/SerialManager.h"
)
target_include_directories(serial_qml_workflow_test PRIVATE "${APP_ROOT}")
target_link_libraries(serial_qml_workflow_test PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::SerialPort)
