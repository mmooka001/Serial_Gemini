import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MySerial_Gemini
import com.gemini.serial

Window {
    id: window
    width: 1250
    height: 850
    minimumWidth: 800
    minimumHeight: 650
    visible: true
    title: qsTr("MySerial Gemini")
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    readonly property bool isNarrow: width < 1100
    readonly property bool isUltraNarrow: width < 900

    property bool isDark: true 
    
    readonly property color clBg: isDark ? "#1e1f22" : "#F8F9FA"
    readonly property color clCard: isDark ? "#2b2d30" : "#FFFFFF"
    readonly property color clInput: isDark ? "#1e1f22" : "#F1F3F4"
    readonly property color clHeader: isDark ? "#2b2d30" : "#FFFFFF"
    readonly property color clText: isDark ? "#afb1b3" : "#444746"
    readonly property color clHighlight: isDark ? "#3574f0" : "#1A73E8"
    readonly property color clBorder: isDark ? "#393b40" : "#DEE2E6"
    readonly property color clAccent: isDark ? "#f26522" : "#D93025"
    readonly property color whiteText: isDark ? "#ffffff" : "#1F1F1F"
    readonly property color grayPlaceholder: isDark ? "#666666" : "#707070"
    readonly property color clTitleBg: isDark ? "#323335" : "#F1F3F4"

    property bool sideBarOpen: false 
    property bool globalRxHex: true 
    property bool globalTxHex: true 
    property bool globalTimestamp: true
    property int currentPageIndex: 0
    property string checksumValue: ChecksumHelper.hexChecksumPreview(sendInput.text, globalTxHex, checksumCombo.currentIndex)

    property string deleteType: ""
    property int targetGroupIdx: -1
    property int targetCmdIdx: -1

    Rectangle {
        id: rootRect
        anchors.fill: parent
        radius: 12
        color: clBg
        border.color: clBorder
        border.width: 1
        clip: true 

        Rectangle {
            id: titleBar
            width: parent.width
            height: 42
            color: clHeader
            radius: 12
            z: 100
            
            Rectangle { 
                width: parent.width
                height: 20
                color: parent.color
                anchors.bottom: parent.bottom 
            }
            
            Rectangle { 
                width: parent.width
                height: 1
                color: clBorder
                anchors.bottom: parent.bottom 
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0
                
                Row {
                    Layout.fillHeight: true
                    spacing: 0
                    Repeater {
                        model: ["主控制台", "系统信息"]
                        Rectangle {
                            width: 110
                            height: 42
                            color: currentPageIndex === index ? clBg : "transparent"
                            Text {
                                text: modelData
                                anchors.centerIn: parent
                                color: currentPageIndex === index ? whiteText : clText
                                font.pixelSize: 12
                                font.bold: currentPageIndex === index
                            }
                            MouseArea { 
                                anchors.fill: parent
                                onClicked: {
                                    currentPageIndex = index 
                                }
                            }
                            Rectangle { 
                                width: parent.width
                                height: 2
                                color: clHighlight
                                anchors.bottom: parent.bottom
                                visible: currentPageIndex === index 
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    MouseArea {
                        anchors.fill: parent
                        onPressed: {
                            window.startSystemMove()
                        }
                        onDoubleClicked: {
                            if (window.visibility === Window.Maximized) {
                                window.showNormal()
                            } else {
                                window.showMaximized()
                            }
                        }
                    }
                }

                Row {
                    Layout.fillHeight: true
                    spacing: 0
                    
                    Text { 
                        text: "GEMINI SERIAL"
                        color: isDark ? "#444" : "#BBB"
                        font.pixelSize: 9
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: 20
                    }

                    Button {
                        id: pinBtn
                        width: 40
                        height: 42
                        flat: true
                        property bool isTop: (window.flags & Qt.WindowStaysOnTopHint)
                        contentItem: Text { 
                            text: "📌"
                            font.pixelSize: 13
                            color: pinBtn.isTop ? clHighlight : clText
                            opacity: pinBtn.isTop ? 1.0 : 0.3
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter 
                        }
                        background: Rectangle { 
                            color: parent.hovered ? (isDark ? "#3e4043" : "#f1f3f4") : "transparent"
                            radius: 8
                        }
                        onClicked: {
                            if (isTop) {
                                window.flags &= ~Qt.WindowStaysOnTopHint
                            } else {
                                window.flags |= Qt.WindowStaysOnTopHint
                            }
                        }
                    }

                    Button {
                        width: 40
                        height: 42
                        flat: true
                        contentItem: Text { 
                            text: isDark ? "☀️" : "🌙"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter 
                        }
                        background: Rectangle { 
                            color: parent.hovered ? (isDark ? "#3e4043" : "#f1f3f4") : "transparent"
                            radius: 21
                        }
                        onClicked: {
                            isDark = !isDark
                        }
                    }

                    Button {
                        width: 45
                        height: 42
                        flat: true
                        contentItem: Text { 
                            text: "—"
                            color: clText
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter 
                        }
                        background: Rectangle { 
                            color: parent.hovered ? (isDark ? "#3e4043" : "#e5e5e5") : "transparent"
                            radius: 8
                        }
                        onClicked: {
                            window.visibility = Window.Minimized
                        }
                    }

                    Button {
                        width: 45
                        height: 42
                        flat: true
                        contentItem: Text { 
                            text: window.visibility === Window.Maximized ? "❐" : "⬜"
                            color: clText
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter 
                        }
                        background: Rectangle { 
                            color: parent.hovered ? (isDark ? "#3e4043" : "#e5e5e5") : "transparent"
                            radius: 8
                        }
                        onClicked: {
                            if (window.visibility === Window.Maximized) {
                                window.showNormal()
                            } else {
                                window.showMaximized()
                            }
                        }
                    }

                    Button {
                        width: 45
                        height: 42
                        flat: true
                        contentItem: Text { 
                            text: "✕"
                            color: clText
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter 
                        }
                        background: Rectangle { 
                            color: parent.hovered ? "#e81123" : "transparent"
                            radius: 12
                            Rectangle {
                                width: 20
                                height: 42
                                color: parent.color
                                anchors.left: parent.left
                                visible: parent.color !== "transparent"
                            }
                            Rectangle {
                                width: 45
                                height: 20
                                color: parent.color
                                anchors.bottom: parent.bottom
                                visible: parent.color !== "transparent"
                            }
                        }
                        onClicked: {
                            Qt.quit()
                        }
                    }
                }
            }
        }

        StackLayout {
            anchors.top: titleBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 15
            currentIndex: currentPageIndex

            RowLayout {
                spacing: 0
                
                Rectangle {
                    id: configCard
                    Layout.preferredWidth: 260
                    Layout.fillHeight: true
                    Layout.rightMargin: 15
                    color: clCard
                    radius: 12
                    border.color: clBorder
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 20
                        
                        Text { text: "连接配置"
                         color: whiteText
                         font.bold: true
                         font.pixelSize: 14 }

                        ColumnLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            RowLayout {
                                Text { text: "选择端口"
                                 color: "#777"
                                 font.pixelSize: 11
                                 Layout.fillWidth: true }
                                Button {
                                    text: "刷新"
                                    flat: true
                                    Layout.preferredHeight: 16
                                    contentItem: Text { text: parent.text
                                     color: clHighlight
                                     font.pixelSize: 10
                                     horizontalAlignment: Text.AlignRight }
                                    onClicked: {
                                        portCombo.model = serialManager.availablePorts()
                                    }
                                }
                            }
                            ComboBox { 
                                id: portCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                model: serialManager.availablePorts()
                                background: Rectangle { color: clInput
                                 radius: 10
                                 border.color: portCombo.activeFocus ? clHighlight : clBorder }
                                contentItem: Text { text: portCombo.currentText
                                 color: whiteText
                                 font.pixelSize: 13
                                 verticalAlignment: Text.AlignVCenter
                                 leftPadding: 15 }
                                popup: Popup {
                                    y: portCombo.height + 5
                                     width: portCombo.width
                                     implicitHeight: 250
                                     padding: 5
                                    contentItem: ListView { clip: true
                                     implicitHeight: contentHeight
                                     model: portCombo.popup.visible ? portCombo.delegateModel : null
                                     ScrollIndicator.vertical: ScrollIndicator { } }
                                    background: Rectangle { color: clCard
                                     radius: 10
                                     border.color: clBorder
                                     border.width: 1 }
                                }
                                delegate: ItemDelegate {
                                    width: portCombo.width
                                    height: 36
                                    contentItem: Text { text: modelData
                                     color: highlighted ? "white" : whiteText
                                     font.pixelSize: 12
                                     verticalAlignment: Text.AlignVCenter
                                     leftPadding: 12 }
                                    background: Rectangle { color: highlighted ? clHighlight : "transparent"
                                     radius: 8 }
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Text { text: "通信波特率"
                             color: "#777"
                             font.pixelSize: 11 }
                            ComboBox { 
                                id: baudCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                model: [9600, 19200, 38400, 57600, 115200, 230400, 256000, 460800, 921600, 1000000, 2000000]
                                currentIndex: 4
                                background: Rectangle { color: clInput
                                 radius: 10
                                 border.color: baudCombo.activeFocus ? clHighlight : clBorder }
                                contentItem: Text { text: baudCombo.currentText
                                 color: whiteText
                                 font.pixelSize: 13
                                 verticalAlignment: Text.AlignVCenter
                                 leftPadding: 15 }
                                popup: Popup {
                                    y: baudCombo.height + 5
                                     width: baudCombo.width
                                     implicitHeight: 250
                                     padding: 5
                                    contentItem: ListView { clip: true
                                     implicitHeight: contentHeight
                                     model: baudCombo.popup.visible ? baudCombo.delegateModel : null
                                     ScrollIndicator.vertical: ScrollIndicator { } }
                                    background: Rectangle { color: clCard
                                     radius: 10
                                     border.color: clBorder
                                     border.width: 1 }
                                }
                                delegate: ItemDelegate {
                                    width: baudCombo.width
                                    height: 36
                                    contentItem: Text { text: modelData
                                     color: highlighted ? "white" : whiteText
                                     font.pixelSize: 12
                                     verticalAlignment: Text.AlignVCenter
                                     leftPadding: 12 }
                                    background: Rectangle { color: highlighted ? clHighlight : "transparent"
                                     radius: 8 }
                                }
                            }
                        }

                        Button {
                            id: connectBtn
                             Layout.fillWidth: true
                             Layout.preferredHeight: 45
                             text: serialManager.isOpen ? "断开当前连接" : "建立串口连接"
                            onClicked: { if (serialManager.isOpen) serialManager.closePort()
                             else serialManager.openPort(portCombo.currentText, parseInt(baudCombo.currentText)) }
                            background: Rectangle { radius: 10
                             color: serialManager.isOpen ? "#3c3f41" : clHighlight }
                            contentItem: Text { text: parent.text
                             color: "white"
                             font.bold: true
                             font.pixelSize: 13
                             horizontalAlignment: Text.AlignHCenter
                             verticalAlignment: Text.AlignVCenter }
                        }

                        Item { Layout.fillHeight: true }
                        
                        Button { 
                            text: sideBarOpen ? "隐藏指令预设" : "显示指令预设"
                            Layout.fillWidth: true
                             Layout.preferredHeight: 38
                            background: Rectangle { color: "transparent"
                             radius: 8
                             border.color: parent.hovered ? clHighlight : "transparent" }
                            contentItem: Text { text: parent.text
                             color: parent.hovered ? clHighlight : "#888"
                             font.pixelSize: 12
                             horizontalAlignment: Text.AlignHCenter
                             verticalAlignment: Text.AlignVCenter }
                            onClicked: { sideBarOpen = !sideBarOpen }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                     Layout.fillHeight: true
                     spacing: 15
                    
                    Rectangle {
                        id: terminalCard
                         Layout.fillWidth: true
                         Layout.fillHeight: true
                         color: clCard
                         radius: 15
                         border.color: clBorder
                        ColumnLayout {
                            anchors.fill: parent
                             anchors.margins: 15
                             spacing: 10
                            RowLayout {
                                Text { text: "数据终端"
                                 color: "#777"
                                 font.pixelSize: 11
                                 font.bold: true }
                                Item { Layout.fillWidth: true }
                                Button { text: "清除"
                                 flat: true
                                 contentItem: Text { text: parent.text
                                 color: "#888"
                                 font.pixelSize: 11 }
                                 background: Rectangle { radius: 6
                                 color: parent.hovered ? Qt.rgba(1,1,1,0.05) : "transparent" }
                                 onClicked: { terminalModel.clear() } }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                 Layout.fillHeight: true
                                 color: clInput
                                 radius: 12
                                 border.color: clBorder
                                ListView {
                                    id: terminalView
                                     anchors.fill: parent
                                     anchors.margins: 15
                                     model: ListModel { id: terminalModel }
                                     spacing: 15
                                     clip: true
                                     boundsBehavior: Flickable.StopAtBounds
                                    delegate: Column {
                                        width: terminalView.width
                                         spacing: 6
                                        RowLayout {
                                            width: parent.width
                                             layoutDirection: model.isSent ? Qt.RightToLeft : Qt.LeftToRight
                                             spacing: 8
                                            Text { text: model.timestamp
                                             font.pixelSize: 9
                                             color: "#555"
                                             visible: globalTimestamp }
                                            Rectangle { 
                                                width: 38
                                                 height: 16
                                                 radius: 4
                                                 border.color: model.isHexMode ? clHighlight : clBorder
                                                 color: model.isHexMode ? Qt.rgba(53/255, 116/255, 240/255, 0.15) : "transparent"
                                                Text { text: model.isHexMode ? "HEX" : "TXT"
                                                 anchors.centerIn: parent
                                                 font.pixelSize: 8
                                                 font.bold: true
                                                 color: model.isHexMode ? clHighlight : "#666" }
                                                MouseArea { anchors.fill: parent
                                                 onClicked: { model.isHexMode = !model.isHexMode } }
                                            }
                                            Item { Layout.fillWidth: true }
                                        }
                                        Row {
                                            width: parent.width
                                             layoutDirection: model.isSent ? Qt.RightToLeft : Qt.LeftToRight
                                            Rectangle {
                                                width: msgText.implicitWidth + 30
                                                 height: msgText.implicitHeight + 20
                                                 radius: 16
                                                 color: model.isSent ? clHighlight : (isDark ? "#323336" : "#E8EAEF")
                                                TextEdit { id: msgText
                                                 text: model.isHexMode ? model.contentHex : model.contentAscii
                                                 width: Math.min(implicitWidth, terminalView.width * 0.75)
                                                 anchors.centerIn: parent
                                                 color: model.isSent ? "white" : whiteText
                                                 font.family: "Consolas"
                                                 font.pixelSize: 13
                                                 readOnly: true
                                                 selectByMouse: true
                                                 wrapMode: Text.Wrap }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: sendCard
                         Layout.fillWidth: true
                         Layout.preferredHeight: 180
                         color: clCard
                         radius: 15
                         border.color: clBorder
                        ColumnLayout {
                            anchors.fill: parent
                             anchors.margins: 15
                             spacing: 12
                            RowLayout {
                                spacing: 12
                                 Layout.fillWidth: true
                                RowLayout {
                                    spacing: 6
                                     Text { text: "接收:"
                                     color: "#777"
                                     font.pixelSize: 10
                                     visible: window.width > 950 }
                                    Row { Repeater { model: ["TXT", "HEX"]
                                     Button { width: window.width > 800 ? 45 : 35
                                     height: 26
                                     property bool active: (index === 1) === globalRxHex
                                     contentItem: Text { text: modelData
                                     color: active ? "white" : "#777"
                                     font.pixelSize: 9
                                     horizontalAlignment: Text.AlignHCenter
                                     verticalAlignment: Text.AlignVCenter }
                                     background: Rectangle { color: active ? clHighlight : clInput
                                     radius: 6
                                     Rectangle { width: 10
                                     height: 26
                                     color: parent.color
                                     anchors.right: parent.right
                                     visible: index === 0 }
                                     Rectangle { width: 10
                                     height: 26
                                     color: parent.color
                                     anchors.left: parent.left
                                     visible: index === 1 } }
                                     onClicked: { globalRxHex = (index === 1) } } } }
                                }
                                RowLayout {
                                    spacing: 6
                                     Text { text: "发送:"
                                     color: "#777"
                                     font.pixelSize: 10
                                     visible: window.width > 950 }
                                    Row { Repeater { model: ["TXT", "HEX"]
                                     Button { width: window.width > 800 ? 50 : 38
                                     height: 26
                                     property bool active: (index === 1) === globalTxHex
                                     contentItem: Text { text: modelData
                                     color: active ? "white" : "#777"
                                     font.pixelSize: 9
                                     horizontalAlignment: Text.AlignHCenter
                                     verticalAlignment: Text.AlignVCenter }
                                     background: Rectangle { color: active ? clHighlight : clInput
                                     radius: 6
                                     Rectangle { width: 10
                                     height: 26
                                     color: parent.color
                                     anchors.right: parent.right
                                     visible: index === 0 }
                                     Rectangle { width: 10
                                     height: 26
                                     color: parent.color
                                     anchors.left: parent.left
                                     visible: index === 1 } }
                                     onClicked: { globalTxHex = (index === 1) } } } }
                                }
                                RowLayout {
                                    spacing: 6
                                     Text { text: "日志:"
                                     color: "#777"
                                     font.pixelSize: 10
                                     visible: window.width > 950 }
                                    Button { width: window.width > 800 ? 45 : 35
                                     height: 26
                                     contentItem: Text { text: "TIME"
                                     color: globalTimestamp ? "white" : "#777"
                                     font.pixelSize: 9
                                     horizontalAlignment: Text.AlignHCenter
                                     verticalAlignment: Text.AlignVCenter }
                                     background: Rectangle { color: globalTimestamp ? clHighlight : clInput
                                     radius: 6 }
                                     onClicked: { globalTimestamp = !globalTimestamp } }
                                }
                                Item { Layout.fillWidth: true }
                                ComboBox { id: checksumCombo
                                 Layout.preferredWidth: window.width > 850 ? 120 : 80
                                 Layout.preferredHeight: 30
                                 model: ["无校验", "BCC", "Sum8", "CRC16"]
                                 background: Rectangle { color: clInput
                                 radius: 8
                                 border.color: clBorder }
                                 contentItem: Text { text: window.width > 850 ? checksumCombo.currentText : "∑" + checksumCombo.currentText
                                 color: clText
                                 font.pixelSize: 11
                                 verticalAlignment: Text.AlignVCenter
                                 leftPadding: 10 } }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                 Layout.fillHeight: true
                                 color: clInput
                                 radius: 12
                                 border.color: sendInput.activeFocus ? clHighlight : "transparent"
                                RowLayout {
                                    anchors.fill: parent
                                     anchors.margins: 8
                                    TextArea { id: sendInput
                                     Layout.fillWidth: true
                                     Layout.fillHeight: true
                                     color: whiteText
                                     font.family: "Consolas"
                                     font.pixelSize: 14
                                     placeholderText: "键入内容并发送..."
                                     placeholderTextColor: grayPlaceholder
                                     background: null
                                     wrapMode: TextArea.Wrap }
                                    Rectangle { Layout.preferredWidth: window.width > 750 ? 80 : 50
                                     Layout.fillHeight: true
                                     color: isDark ? "#232428" : "#E8EAEF"
                                     radius: 8
                                     visible: checksumCombo.currentIndex > 0
                                     Column { anchors.centerIn: parent
                                     spacing: 2
                                     Text { text: "校验"
                                     color: "#777"
                                     font.pixelSize: 9
                                     visible: window.width > 750 }
                                     Text { text: checksumValue
                                     color: clAccent
                                     font.bold: true
                                     font.pixelSize: 13 } } }
                                    Button { id: sendBtn
                                     Layout.preferredWidth: window.width > 750 ? 80 : 55
                                     Layout.fillHeight: true
                                     text: window.width > 750 ? "发送" : "➤"
                                     onClicked: { if (checksumCombo.currentIndex > 0) { serialManager.sendDataWithChecksum(sendInput.text, globalTxHex, checksumCombo.currentIndex) } else { serialManager.sendData(sendInput.text, globalTxHex) } }
                                     background: Rectangle { color: clHighlight
                                     radius: 10 }
                                     contentItem: Text { text: parent.text
                                     color: "white"
                                     font.bold: true
                                     font.pixelSize: window.width > 750 ? 13 : 18
                                     horizontalAlignment: Text.AlignHCenter
                                     verticalAlignment: Text.AlignVCenter } }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: commandSideBar
                     Layout.preferredWidth: sideBarOpen ? 300 : 0
                     Layout.fillHeight: true
                     Layout.leftMargin: sideBarOpen ? 15 : 0
                     color: clCard
                     radius: 15
                     border.color: clBorder
                     clip: true
                    Behavior on Layout.preferredWidth { SpringAnimation { spring: 3
                     damping: 0.7 } }
                    Behavior on Layout.leftMargin { NumberAnimation { duration: 200 } }
                    
                    ColumnLayout {
                        width: 300
                         height: parent.height
                         anchors.margins: 0
                         spacing: 15
                        RowLayout {
                            Layout.fillWidth: true
                             Layout.topMargin: 20
                             Layout.leftMargin: 15
                             Layout.rightMargin: 15
                            Text { text: "指令预设库"
                             color: clHighlight
                             font.bold: true
                             font.pixelSize: 15 }
                            Item { Layout.fillWidth: true }
                            Button { text: "＋分组"
                             flat: true
                             contentItem: Text { text: parent.text
                             color: clHighlight
                             font.pixelSize: 11
                             font.bold: true }
                             background: Rectangle { radius: 8
                             color: parent.hovered ? Qt.rgba(1,1,1,0.05) : "transparent" }
                             onClicked: { commandStore.addGroup("新分组") } }
                        }
                        Rectangle {
                            id: searchBox
                            Layout.fillWidth: true
                             Layout.preferredHeight: 38
                             Layout.leftMargin: 20
                             Layout.rightMargin: 20
                             Layout.topMargin: 5
                             color: clInput
                             radius: 10
                            TextField { 
                                id: searchField
                                anchors.left: parent.left
                                 anchors.right: parent.right
                                 anchors.top: parent.top
                                 anchors.bottom: parent.bottom
                                anchors.topMargin: activeFocus ? 3 : 0 // 仅文字输入区平滑下移，方框不动
                                leftPadding: 35
                                 placeholderText: "搜索指令..."
                                 color: whiteText
                                 font.pixelSize: 12
                                 background: null
                                Behavior on anchors.topMargin { NumberAnimation { duration: 150
                                 easing.type: Easing.OutQuad } }
                                Text { text: "🔍"
                                 x: 12
                                 anchors.verticalCenter: parent.verticalCenter
                                 opacity: 0.4
                                 color: clText
                                 anchors.verticalCenterOffset: searchField.activeFocus ? -2 : 0 }
                            }
                        }
                        ListView {
                            id: groupList
                             Layout.fillWidth: true
                             Layout.fillHeight: true
                             model: commandStore.groups
                             spacing: 12
                             clip: true
                            delegate: ColumnLayout {
                                width: groupList.width
                                 spacing: 8
                                 property int groupIdx: index
                                Rectangle {
                                    Layout.fillWidth: true
                                     height: 38
                                     color: Qt.rgba(1, 1, 1, 0.03)
                                     radius: 10
                                     Layout.leftMargin: 10
                                     Layout.rightMargin: 10
                                    RowLayout {
                                        anchors.fill: parent
                                         anchors.leftMargin: 10
                                         anchors.rightMargin: 10
                                        Text { text: "📂 " + modelData.name
                                         color: whiteText
                                         font.bold: true
                                         font.pixelSize: 12
                                         Layout.fillWidth: true }
                                        Button { text: "＋"
                                         width: 24
                                         flat: true
                                         contentItem: Text { text: parent.text
                                         color: clHighlight
                                         font.pixelSize: 14
                                         horizontalAlignment: Text.AlignHCenter }
                                         background: Rectangle { radius: 8
                                         color: parent.hovered ? Qt.rgba(1,1,1,0.05) : "transparent" }
                                         onClicked: { commandStore.addCommand(groupIdx, "新指令", "", globalTxHex) } }
                                        Button { text: "✕"
                                         width: 24
                                         flat: true
                                         contentItem: Text { text: parent.text
                                         color: "#666"
                                         font.pixelSize: 12
                                         horizontalAlignment: Text.AlignHCenter }
                                         background: Rectangle { radius: 8
                                         color: parent.hovered ? Qt.rgba(1,0,0,0.1) : "transparent" }
                                         onClicked: { deleteType = "group"
                                         targetGroupIdx = groupIdx
                                         deleteConfirmOverlay.visible = true } }
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                     spacing: 6
                                     Layout.leftMargin: 15
                                     Layout.rightMargin: 15
                                    Repeater {
                                        model: modelData.commands
                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                             height: 65
                                             radius: 12
                                             color: Qt.rgba(1, 1, 1, 0.02)
                                             border.color: clBorder
                                            ColumnLayout {
                                                anchors.fill: parent
                                                 anchors.margins: 8
                                                 spacing: 4
                                                RowLayout {
                                                    TextField { text: modelData.name
                                                     color: whiteText
                                                     font.bold: true
                                                     font.pixelSize: 11
                                                     Layout.fillWidth: true
                                                     background: null
                                                     onEditingFinished: { commandStore.updateCommand(groupIdx, index, text, modelData.payload) } }
                                                    Button { text: "🚀"
                                                     width: 24
                                                     height: 24
                                                     flat: true
                                                     background: Rectangle { radius: 8
                                                     color: parent.hovered ? Qt.rgba(1,1,1,0.05) : "transparent" }
                                                     onClicked: { serialManager.sendData(modelData.payload, modelData.isHex) } }
                                                    Button { text: "✕"
                                                     width: 24
                                                     height: 24
                                                     flat: true
                                                     contentItem: Text { text: parent.text
                                                     color: "#666"
                                                     horizontalAlignment: Text.AlignHCenter }
                                                     background: Rectangle { radius: 8
                                                     color: parent.hovered ? Qt.rgba(1,0,0,0.1) : "transparent" }
                                                     onClicked: { deleteType = "cmd"
                                                     targetGroupIdx = groupIdx
                                                     targetCmdIdx = index
                                                     deleteConfirmOverlay.visible = true } }
                                                }
                                                TextField { text: modelData.payload
                                                 color: clText
                                                 font.family: "Consolas"
                                                 font.pixelSize: 10
                                                 Layout.fillWidth: true
                                                 background: Rectangle { color: clInput
                                                 radius: 6 }
                                                 onEditingFinished: { commandStore.updateCommand(groupIdx, index, modelData.name, text) } }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: deleteConfirmOverlay
             anchors.fill: parent
             z: 5000
             visible: false
             color: Qt.rgba(0, 0, 0, 0.7)
            Rectangle {
                width: 320
                 height: 180
                 radius: 15
                 anchors.centerIn: parent
                 color: clCard
                 border.color: clHighlight
                 border.width: 1
                ColumnLayout {
                    anchors.fill: parent
                     anchors.margins: 25
                     spacing: 20
                    Text { text: "确定要执行删除吗？"
                     color: whiteText
                     font.bold: true
                     font.pixelSize: 16
                     Layout.alignment: Qt.AlignHCenter }
                    Text { text: "操作后数据将无法恢复"
                     color: "#888"
                     font.pixelSize: 12
                     Layout.alignment: Qt.AlignHCenter }
                    RowLayout {
                        spacing: 15
                         Layout.fillWidth: true
                        Button { text: "取消"
                         Layout.fillWidth: true
                         Layout.preferredHeight: 38
                         background: Rectangle { radius: 10
                         color: "#333" }
                         contentItem: Text { text: parent.text
                         color: "white"
                         horizontalAlignment: Text.AlignHCenter }
                         onClicked: { deleteConfirmOverlay.visible = false } }
                        Button { text: "确定删除"
                         Layout.fillWidth: true
                         Layout.preferredHeight: 38
                         background: Rectangle { radius: 10
                         color: clAccent }
                         contentItem: Text { text: parent.text
                         color: "white"
                         font.bold: true
                         horizontalAlignment: Text.AlignHCenter }
                         onClicked: { if (deleteType === "group") { commandStore.deleteGroup(targetGroupIdx) } else if (deleteType === "cmd") { commandStore.deleteCommand(targetGroupIdx, targetCmdIdx) } 
                         deleteConfirmOverlay.visible = false } }
                    }
                }
            }
        }

        MouseArea { width: 6
         anchors.left: parent.left
         anchors.top: parent.top
         anchors.bottom: parent.bottom
         cursorShape: Qt.SizeHorCursor
         onPressed: { window.startSystemResize(Qt.LeftEdge) } }
        MouseArea { width: 6
         anchors.right: parent.right
         anchors.top: parent.top
         anchors.bottom: parent.bottom
         cursorShape: Qt.SizeHorCursor
         onPressed: { window.startSystemResize(Qt.RightEdge) } }
        MouseArea { height: 6
         anchors.top: parent.top
         anchors.left: parent.left
         anchors.right: parent.right
         cursorShape: Qt.SizeVerCursor
         onPressed: { window.startSystemResize(Qt.TopEdge) } }
        MouseArea { height: 6
         anchors.bottom: parent.bottom
         anchors.left: parent.left
         anchors.right: parent.right
         cursorShape: Qt.SizeVerCursor
         onPressed: { window.startSystemResize(Qt.BottomEdge) } }
        MouseArea { width: 12
         height: 12
         anchors.left: parent.left
         anchors.top: parent.top
         cursorShape: Qt.SizeFDiagCursor
         onPressed: { window.startSystemResize(Qt.TopEdge | Qt.LeftEdge) } }
        MouseArea { width: 12
         height: 12
         anchors.right: parent.right
         anchors.top: parent.top
         cursorShape: Qt.SizeBDiagCursor
         onPressed: { window.startSystemResize(Qt.TopEdge | Qt.RightEdge) } }
        MouseArea { width: 12
         height: 12
         anchors.left: parent.left
         anchors.bottom: parent.bottom
         cursorShape: Qt.SizeBDiagCursor
         onPressed: { window.startSystemResize(Qt.BottomEdge | Qt.LeftEdge) } }
        MouseArea { width: 12
         height: 12
         anchors.right: parent.right
         anchors.bottom: parent.bottom
         cursorShape: Qt.SizeFDiagCursor
         onPressed: { window.startSystemResize(Qt.BottomEdge | Qt.RightEdge) } }
    }

    Connections {
        target: serialManager
        function onDataReceived(ascii, hex, isSent) {
            terminalModel.append({ "contentAscii": ascii, "contentHex": hex, "isHexMode": isSent ? globalTxHex : globalRxHex, "isSent": isSent, "timestamp": Qt.formatDateTime(new Date(), "hh:mm:ss.zzz") })
        }
    }
}
