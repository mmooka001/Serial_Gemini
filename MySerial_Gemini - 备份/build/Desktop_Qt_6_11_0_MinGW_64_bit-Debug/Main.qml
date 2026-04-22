import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MySerial_Gemini

Window {
    id: window
    width: 1100
    height: 750
    visible: true
    title: qsTr("MySerial Gemini")
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    // Background Image/Gradient
    Rectangle {
        anchors.fill: parent
        radius: 15
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0f0c29" }
            GradientStop { position: 0.5; color: "#302b63" }
            GradientStop { position: 1.0; color: "#24243e" }
        }
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
        clip: true

        // Main Layout
        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Sidebar (Glass Panel)
            Rectangle {
                id: sidebar
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    Text {
                        text: "SETTINGS"
                        color: "white"
                        font.bold: true
                        font.letterSpacing: 2
                        font.pixelSize: 14
                        opacity: 0.6
                    }

                    // Port Selection
                    Column {
                        spacing: 5
                        Text { text: "Serial Port"; color: "#aaa"; font.pixelSize: 12 }
                        ComboBox {
                            id: portCombo
                            width: parent.width
                            model: serialManager.availablePorts()
                            onPressedChanged: if (pressed) model = serialManager.availablePorts()
                        }
                    }

                    // Baud Rate
                    Column {
                        spacing: 5
                        Text { text: "Baud Rate"; color: "#aaa"; font.pixelSize: 12 }
                        ComboBox {
                            id: baudCombo
                            width: parent.width
                            model: [9600, 19200, 38400, 57600, 115200]
                            currentIndex: 4
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: serialManager.isOpen ? "CLOSE PORT" : "OPEN PORT"
                        flat: true
                        
                        background: Rectangle {
                            color: serialManager.isOpen ? "#e74c3c" : "#2ecc71"
                            radius: 8
                            opacity: parent.down ? 0.7 : 0.9
                            
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            scale: parent.down ? 0.95 : 1.0
                            Behavior on scale { SpringAnimation { spring: 3; damping: 0.2 } }
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.bold: true
                        }
                        
                        onClicked: {
                            if (serialManager.isOpen) {
                                serialManager.closePort();
                            } else {
                                serialManager.openPort(portCombo.currentText, parseInt(baudCombo.currentText));
                            }
                        }
                    }

                    Item { Layout.fillHeight: true } // Spacer
                }
            }

            // Main Content Area
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                anchors.margins: 20
                spacing: 15

                // Data Display Area
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Qt.rgba(0, 0, 0, 0.3)
                    radius: 12
                    border.color: Qt.rgba(1, 1, 1, 0.05)

                    ScrollView {
                        anchors.fill: parent
                        TextArea {
                            id: receiveArea
                            readOnly: true
                            color: "#00ff00"
                            font.family: "Consolas"
                            font.pixelSize: 14
                            placeholderText: "Waiting for data..."
                            placeholderTextColor: "#444"
                            wrapMode: TextEdit.Wrap
                        }
                    }
                }

                // Input and Send Area
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    color: Qt.rgba(1, 1, 1, 0.05)
                    radius: 12
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        
                        TextArea {
                            id: sendInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "white"
                            placeholderText: "Type message here..."
                            background: null
                        }
                        
                        ColumnLayout {
                            spacing: 10
                            CheckBox {
                                id: hexCheck
                                text: "HEX"
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    leftPadding: parent.indicator.width + parent.spacing
                                }
                            }
                            Button {
                                text: "SEND"
                                Layout.preferredWidth: 80
                                onClicked: serialManager.sendData(sendInput.text, hexCheck.checked)
                            }
                        }
                    }
                }
            }
        }
        
        // Window Controls (Title Bar)
        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            spacing: 10
            
            Rectangle {
                width: 12; height: 12; radius: 6; color: "#f1c40f"
                MouseArea { anchors.fill: parent; onClicked: window.showMinimized() }
            }
            Rectangle {
                width: 12; height: 12; radius: 6; color: "#e74c3c"
                MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
            }
        }
        
        // Window Drag Area
        MouseArea {
            anchors.fill: parent
            z: -1
            property point lastMousePos: Qt.point(0, 0)
            onPressed: lastMousePos = Qt.point(mouseX, mouseY)
            onPositionChanged: {
                if (pressed) {
                    window.x += mouseX - lastMousePos.x
                    window.y += mouseY - lastMousePos.y
                }
            }
        }
    }

    Connections {
        target: serialManager
        function onDataReceived(data, isHex) {
            if (isHex === hexCheck.checked) {
                receiveArea.append(data);
            }
        }
    }
}
