import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MySerial_Gemini
import com.gemini.serial
import QtQuick.Dialogs

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

    property int activePanel: -1          // -1=none, 0=指令, 1=码表, 2=设置
    property int featurePanelWidth: 300
    property int clickOffset: 0           // Click animation offset
    readonly property int centerWidth: width - 260 - (activePanel >= 0 ? featurePanelWidth + 50 + 8 : 50) - 46
    property bool globalRxHex: true 
    property bool globalTxHex: true 
    property bool globalTimestamp: true
    property int currentPageIndex: 0
    property bool autoScroll: true
    property string checksumValue: ChecksumHelper.hexChecksumPreview(sendInput.text, globalTxHex, checksumCombo.currentIndex)

    // Send history
    property var sendHistory: []
    property int historyIndex: -1  // -1 = current input, 0+ = history position

    // Auto-send
    property bool autoSending: false
    property int autoSendInterval: 1000

    // Loop send
    property var loopCmds: []
    property int loopIndex: -1
    property bool loopSending: false

    Timer {
        id: autoSendTimer
        interval: autoSendInterval
        repeat: true
        onTriggered: {
            if (sendInput.text.length > 0) {
                if (checksumCombo.currentIndex > 0) {
                    serialManager.sendDataWithChecksum(sendInput.text, globalTxHex, checksumCombo.currentIndex)
                } else {
                    serialManager.sendData(sendInput.text, globalTxHex)
                }
            }
        }
    }

    Timer {
        id: loopTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (!loopSending || loopIndex >= loopCmds.length) {
                loopSending = false
                loopIndex = -1
                return
            }
            var cmd = loopCmds[loopIndex]
            window.sendCommand(cmd.payload, cmd.isHex)
            loopIndex++
            if (loopIndex < loopCmds.length) {
                loopTimer.start()
            } else {
                loopSending = false
                loopIndex = -1
            }
        }
    }

    function startLoopSend() {
        if (loopSending) return
        var cmds = []
        for (var key in checkedMap) {
            var parts = key.split(":")
            var gIdx = parseInt(parts[0])
            var cIdx = parseInt(parts[1])
            if (commandStore.groups[gIdx] && commandStore.groups[gIdx].commands[cIdx]) {
                var cmd = commandStore.groups[gIdx].commands[cIdx]
                cmds.push({ payload: cmd.payload, isHex: cmd.isHex || false })
            }
        }
        if (cmds.length === 0) return
        loopCmds = cmds
        loopIndex = 0
        loopSending = true
        loopTimer.start()
    }

    property string deleteType: ""
    property int targetGroupIdx: -1
    property int targetCmdIdx: -1
    property var checkedMap: ({})

    function sendCommand(payload, isHex) {
        if (!serialManager.isOpen) return
        serialManager.sendData(payload, isHex)
    }

    function doSend() {
        if (sendInput.text.length === 0) return
        // Record to history
        var h = sendHistory.slice()
        h.unshift(sendInput.text)
        if (h.length > 50) h.pop()
        sendHistory = h
        historyIndex = -1

        if (checksumCombo.currentIndex > 0) {
            serialManager.sendDataWithChecksum(sendInput.text, globalTxHex, checksumCombo.currentIndex)
        } else {
            serialManager.sendData(sendInput.text, globalTxHex)
        }
    }

    function navigateHistory(direction) {
        if (sendHistory.length === 0) return
        if (direction === "up") {
            if (historyIndex < sendHistory.length - 1) {
                historyIndex++
            }
        } else {
            if (historyIndex > 0) {
                historyIndex--
            } else if (historyIndex === 0) {
                historyIndex = -1
            }
        }
        if (historyIndex === -1) {
            sendInput.text = ""
        } else {
            sendInput.text = sendHistory[historyIndex]
        }
    }

    Rectangle {
        id: rootRect
        anchors.fill: parent
        radius: 12
        color: clBg
        border.color: clBorder
        border.width: 1
        antialiasing: true
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
                        property bool isTop: false
                        contentItem: Text { 
                            text: "📌"
                            font.pixelSize: 13
                            color: pinBtn.isTop ? clHighlight : (pinBtn.hovered ? whiteText : clText)
                            opacity: pinBtn.isTop ? 1.0 : (pinBtn.hovered ? 0.9 : 0.3)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter 
                        }
                        background: Rectangle { 
                            anchors.fill: parent
                            anchors.margins: 4
                            color: pinBtn.hovered ? (isDark ? "#3e4043" : "#f1f3f4") : "transparent"
                            radius: 8
                        }
                        onClicked: {
                            pinBtn.isTop = !pinBtn.isTop
                            serialManager.setStayOnTop(window, pinBtn.isTop)
                        }
                    }

                    Button {
                        id: themeBtn
                        width: 40
                        height: 42
                        flat: true
                        padding: 0
                        contentItem: Text { 
                            text: isDark ? "☀️" : "🌙"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter 
                        }
                        background: Rectangle { 
                            anchors.fill: parent
                            anchors.margins: 4
                            color: themeBtn.hovered ? (isDark ? "#3e4043" : "#f1f3f4") : "transparent"
                            radius: 16
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
            anchors.bottom: statusBar.top
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
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 0
                        contentHeight: configColumn.implicitHeight + 40
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: configColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 20
                        spacing: 16
                        
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
                                textRole: "name"
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
                                     implicitHeight: Math.min(contentItem.implicitHeight, 250)
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
                                    contentItem: Text { text: modelData.name
                                     color: highlighted ? "white" : whiteText
                                     font.pixelSize: 12
                                     verticalAlignment: Text.AlignVCenter
                                     leftPadding: 12 }
                                    background: Rectangle { color: highlighted ? clHighlight : "transparent"
                                     radius: 8 }
                                    
                                    // 悬停提示：显示串口描述
                                    ToolTip.visible: hovered
                                    ToolTip.delay: 300
                                    ToolTip.text: modelData.description + (modelData.manufacturer ? "\n(" + modelData.manufacturer + ")" : "")
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

                        ColumnLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Text { text: "数据位"
                             color: "#777"
                             font.pixelSize: 11 }
                            ComboBox {
                                id: dataBitsCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                model: [5, 6, 7, 8]
                                currentIndex: 3
                                background: Rectangle { color: clInput
                                 radius: 8
                                 border.color: dataBitsCombo.activeFocus ? clHighlight : clBorder }
                                contentItem: Text { text: dataBitsCombo.currentText
                                 color: whiteText
                                 font.pixelSize: 12
                                 verticalAlignment: Text.AlignVCenter
                                 leftPadding: 12 }
                                popup: Popup {
                                    y: dataBitsCombo.height + 3
                                     width: dataBitsCombo.width
                                     implicitHeight: Math.min(contentItem.implicitHeight, 200)
                                     padding: 3
                                    contentItem: ListView { clip: true
                                     implicitHeight: contentHeight
                                     model: dataBitsCombo.popup.visible ? dataBitsCombo.delegateModel : null }
                                    background: Rectangle { color: clCard; radius: 8; border.color: clBorder; border.width: 1 }
                                }
                                delegate: ItemDelegate {
                                    width: dataBitsCombo.width; height: 32
                                    contentItem: Text { text: modelData; color: highlighted ? "white" : whiteText; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; leftPadding: 12 }
                                    background: Rectangle { color: highlighted ? clHighlight : "transparent"; radius: 6 }
                                }
                            }
                        }

                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "停止位"; color: "#777"; font.pixelSize: 10 }
                                ComboBox {
                                    id: stopBitsCombo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    model: ["1", "1.5", "2"]
                                    currentIndex: 0
                                    background: Rectangle { color: clInput; radius: 8; border.color: stopBitsCombo.activeFocus ? clHighlight : clBorder }
                                    contentItem: Text { text: stopBitsCombo.currentText; color: whiteText; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; leftPadding: 10 }
                                    popup: Popup {
                                        y: stopBitsCombo.height + 3; width: stopBitsCombo.width; implicitHeight: contentItem.implicitHeight; padding: 3
                                        contentItem: ListView { clip: true; implicitHeight: contentHeight; model: stopBitsCombo.popup.visible ? stopBitsCombo.delegateModel : null }
                                        background: Rectangle { color: clCard; radius: 8; border.color: clBorder }
                                    }
                                    delegate: ItemDelegate {
                                        width: stopBitsCombo.width; height: 30
                                        contentItem: Text { text: modelData; color: highlighted ? "white" : whiteText; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; leftPadding: 10 }
                                        background: Rectangle { color: highlighted ? clHighlight : "transparent"; radius: 6 }
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "校验位"; color: "#777"; font.pixelSize: 10 }
                                ComboBox {
                                    id: parityCombo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    model: ["None", "Odd", "Even", "Mark", "Space"]
                                    currentIndex: 0
                                    background: Rectangle { color: clInput; radius: 8; border.color: parityCombo.activeFocus ? clHighlight : clBorder }
                                    contentItem: Text { text: parityCombo.currentText; color: whiteText; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; leftPadding: 10 }
                                    popup: Popup {
                                        y: parityCombo.height + 3; width: parityCombo.width; implicitHeight: contentItem.implicitHeight; padding: 3
                                        contentItem: ListView { clip: true; implicitHeight: contentHeight; model: parityCombo.popup.visible ? parityCombo.delegateModel : null }
                                        background: Rectangle { color: clCard; radius: 8; border.color: clBorder }
                                    }
                                    delegate: ItemDelegate {
                                        width: parityCombo.width; height: 30
                                        contentItem: Text { text: modelData; color: highlighted ? "white" : whiteText; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; leftPadding: 10 }
                                        background: Rectangle { color: highlighted ? clHighlight : "transparent"; radius: 6 }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Text { text: "流控制"
                             color: "#777"
                             font.pixelSize: 11 }
                            ComboBox {
                                id: flowCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                model: ["None", "Hardware", "Software"]
                                currentIndex: 0
                                background: Rectangle { color: clInput; radius: 8; border.color: flowCombo.activeFocus ? clHighlight : clBorder }
                                contentItem: Text { text: flowCombo.currentText; color: whiteText; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; leftPadding: 12 }
                                popup: Popup {
                                    y: flowCombo.height + 3; width: flowCombo.width; implicitHeight: contentItem.implicitHeight; padding: 3
                                    contentItem: ListView { clip: true; implicitHeight: contentHeight; model: flowCombo.popup.visible ? flowCombo.delegateModel : null }
                                    background: Rectangle { color: clCard; radius: 8; border.color: clBorder }
                                }
                                delegate: ItemDelegate {
                                    width: flowCombo.width; height: 32
                                    contentItem: Text { text: modelData; color: highlighted ? "white" : whiteText; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; leftPadding: 12 }
                                    background: Rectangle { color: highlighted ? clHighlight : "transparent"; radius: 6 }
                                }
                            }
                        }

                        Button {
                            id: connectBtn
                             Layout.fillWidth: true
                             Layout.preferredHeight: 45
                             text: serialManager.isOpen ? "断开当前连接" : "建立串口连接"
                            onClicked: {
                                if (serialManager.isOpen) {
                                    serialManager.closePort()
                                } else {
                                    serialManager.openPort(
                                        portCombo.currentText,
                                        parseInt(baudCombo.currentText),
                                        parseInt(dataBitsCombo.currentText),
                                        stopBitsCombo.currentIndex + 1,  // 1=OneStop, 2=OneAndHalf, 3=TwoStop
                                        parityCombo.currentIndex,        // 0=None, 1=Odd, 2=Even, 3=Mark, 4=Space
                                        flowCombo.currentIndex           // 0=None, 1=HW, 2=SW
                                    )
                                }
                            }
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
                    }
                    } // Flickable
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
                                
                                // 自动滚动开关
                                Button {
                                    id: scrollToggle
                                    flat: true
                                    contentItem: Text { 
                                        text: autoScroll ? "🔓 自动滚动" : "🔒 锁定滚动"
                                        color: autoScroll ? clHighlight : "#888"
                                        font.pixelSize: 10
                                    }
                                    onClicked: autoScroll = !autoScroll
                                }

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
                                         property bool delegateHover: false
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
                                            // Copy button (appears on hover)
                                            Rectangle {
                                                width: 16; height: 16; radius: 3
                                                color: copyMsgMouse.containsMouse ? (isDark ? "#555" : "#DDD") : "transparent"
                                                visible: delegateHover
                                                Text { text: "📋"; font.pixelSize: 9; anchors.centerIn: parent }
                                                MouseArea {
                                                    id: copyMsgMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        var txt = model.isHexMode ? model.contentHex : model.contentAscii
                                                        serialManager.copyToClipboard(txt)
                                                    }
                                                }
                                            }
                                            Item { Layout.fillWidth: true }
                                        }
                                        // Mouse area for hover detection on the whole message
                                        MouseArea {
                                            width: parent.width
                                            height: msgRow.height
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            onContainsMouseChanged: delegateHover = containsMouse
                                        }
                                        Row {
                                            id: msgRow
                                            width: parent.width
                                             layoutDirection: model.isSent ? Qt.RightToLeft : Qt.LeftToRight
                                            Rectangle {
                                                width: msgText.implicitWidth + 30
                                                 height: msgText.implicitHeight + 14
                                                 radius: 16
                                                 color: model.isSent ? clHighlight : (isDark ? "#323336" : "#E8EAEF")
                                                TextEdit { id: msgText
                                                 text: model.isHexMode ? model.contentHex : model.contentAscii
                                                 width: Math.min(implicitWidth, terminalView.width * 0.75)
                                                 anchors.centerIn: parent
                                                 verticalAlignment: Text.AlignVCenter
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
                                     visible: centerWidth > 350 }
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
                                     visible: centerWidth > 350 }
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
                                     visible: centerWidth > 420 }
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
                                ComboBox { 
                                    id: checksumCombo
                                    Layout.preferredWidth: window.width > 850 ? 120 : 80
                                    Layout.preferredHeight: 30
                                    model: ["无校验", "BCC", "Sum8", "CRC16"]
                                    background: Rectangle { 
                                        color: clInput
                                        radius: 8
                                        border.color: checksumCombo.activeFocus ? clHighlight : clBorder 
                                    }
                                    contentItem: Text { 
                                        text: window.width > 850 ? checksumCombo.currentText : "∑ " + checksumCombo.currentText
                                        color: clText
                                        font.pixelSize: 11
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 10 
                                    }
                                    popup: Popup {
                                        y: checksumCombo.height + 3
                                        width: checksumCombo.width
                                        implicitHeight: contentItem.implicitHeight
                                        padding: 5
                                        contentItem: ListView {
                                            clip: true
                                            implicitHeight: contentHeight
                                            model: checksumCombo.popup.visible ? checksumCombo.delegateModel : null
                                        }
                                        background: Rectangle { 
                                            color: clCard
                                            radius: 10
                                            border.color: clBorder
                                            border.width: 1 
                                        }
                                    }
                                    delegate: ItemDelegate {
                                        width: checksumCombo.width
                                        height: 32
                                        contentItem: Text { 
                                            text: modelData
                                            color: highlighted ? "white" : whiteText
                                            font.pixelSize: 11
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 10 
                                        }
                                        background: Rectangle { 
                                            color: highlighted ? clHighlight : "transparent"
                                            radius: 6 
                                        }
                                    }
                                }
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
                                     wrapMode: TextArea.Wrap
                                     Keys.onUpPressed: function(event) {
                                         if (sendInput.cursorPosition === 0 || sendInput.text === "") {
                                             navigateHistory("up")
                                             event.accepted = true
                                         } else {
                                             event.accepted = false
                                         }
                                     }
                                     Keys.onDownPressed: function(event) {
                                         if (historyIndex >= 0) {
                                             navigateHistory("down")
                                             event.accepted = true
                                         } else {
                                             event.accepted = false
                                         }
                                     }
                                     Keys.onReturnPressed: function(event) {
                                         if (event.modifiers & Qt.ShiftModifier) {
                                             doSend()
                                             event.accepted = true
                                         } else {
                                             event.accepted = false
                                         }
                                     } }
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
                                     onClicked: doSend()
                                     background: Rectangle { color: clHighlight
                                     radius: 10 }
                                     contentItem: Text { text: parent.text
                                     color: "white"
                                     font.bold: true
                                     font.pixelSize: window.width > 750 ? 13 : 18
                                     horizontalAlignment: Text.AlignHCenter
                                     verticalAlignment: Text.AlignVCenter } }

                                    // Auto-send button
                                    Button {
                                        id: autoSendBtn
                                        Layout.preferredWidth: window.width > 750 ? 60 : 40
                                        Layout.fillHeight: true
                                        text: autoSending ? "⏹" : (window.width > 750 ? "自动" : "⏱")
                                        onClicked: {
                                            if (autoSending) {
                                                autoSendTimer.stop()
                                                autoSending = false
                                            } else {
                                                autoSendTimer.start()
                                                autoSending = true
                                            }
                                        }
                                        background: Rectangle {
                                            radius: 10
                                            color: autoSending ? "#e53935" : (autoSendBtn.hovered ? (isDark ? "#3e4043" : "#E8EAED") : clInput)
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: autoSending ? "white" : clText
                                            font.bold: true
                                            font.pixelSize: window.width > 750 ? 12 : 16
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Right Column: Feature Panel + Activity Bar ──
                Item {
                    Layout.preferredWidth: activePanel >= 0 ? (featurePanelWidth + 50) : 50
                    Layout.fillHeight: true
                    Layout.leftMargin: 8 + clickOffset
                    clip: true

                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    // Feature Panel (slides out from left of activity bar)
                    Rectangle {
                        id: featurePanel
                        width: activePanel >= 0 ? featurePanelWidth : 0
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: activityBar.left
                        color: clCard
                        radius: 12
                        border.color: clBorder
                        clip: true

                        visible: activePanel >= 0

                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        // Drag handle on left edge for resizing
                        MouseArea {
                            id: panelDragHandle
                            width: 6
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            cursorShape: Qt.SizeHorCursor
                            property real dragStartX: 0
                            property int dragStartWidth: 0
                            onPressed: function(mouse) {
                                dragStartX = mouse.x
                                dragStartWidth = featurePanelWidth
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed) {
                                    var delta = dragStartX - mouse.x
                                    var newWidth = Math.max(200, Math.min(500, dragStartWidth + delta))
                                    featurePanelWidth = newWidth
                                }
                            }
                        }

                        StackLayout {
                            id: featurePanelStack
                            anchors.fill: parent
                            anchors.margins: 12
                            currentIndex: activePanel >= 0 ? activePanel : 0

                            // Tab 0: 指令 (Command Presets)
                            ColumnLayout {
                                spacing: 8

                                // Header
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "指令预设库"
                                        color: clHighlight
                                        font.bold: true
                                        font.pixelSize: 15
                                    }
                                    Item { Layout.fillWidth: true }
                                    Button {
                                        text: "＋分组"
                                        flat: true
                                        font.pixelSize: 12
                                        contentItem: Text {
                                            text: parent.text
                                            color: clHighlight
                                            font: parent.font
                                        }
                                        background: Rectangle { color: "transparent" }
                                        onClicked: commandStore.addGroup("新分组")
                                    }
                                }

                                // Search Box
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 36
                                    radius: 8
                                    color: clInput
                                    border.color: clBorder
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 0

                                        Text {
                                            text: "🔍"
                                            font.pixelSize: 13
                                            color: grayPlaceholder
                                        }

                                        TextField {
                                            id: cmdSearchField
                                            Layout.fillWidth: true
                                            placeholderText: "搜索指令..."
                                            placeholderTextColor: grayPlaceholder
                                            background: Rectangle { color: "transparent" }
                                            color: whiteText
                                            font.pixelSize: 12
                                            leftPadding: 8
                                            selectByMouse: true
                                        }
                                    }
                                }

                                // Command List
                                ListView {
                                    id: cmdListView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 6
                                    model: commandStore.groups

                                    delegate: ColumnLayout {
                                        width: cmdListView.width
                                        spacing: 4

                                        property var group: modelData
                                        property bool groupExpanded: true

                                        // Group Header
                                        Rectangle {
                                            id: groupHeaderRect
                                            Layout.fillWidth: true
                                            height: 38
                                            radius: 10
                                            color: groupHeaderMouse.containsMouse
                                                   ? (isDark ? "#45484b" : "#E8EAED")
                                                   : (isDark ? "#3a3d40" : "#FFFFFF")
                                            border.color: isDark ? "#3a3d40" : "#DEE2E6"
                                            border.width: isDark ? 0 : 1

                                            // Left accent bar
                                            Rectangle {
                                                width: 3
                                                height: parent.height - 4
                                                anchors.left: parent.left
                                                anchors.leftMargin: 1
                                                anchors.verticalCenter: parent.verticalCenter
                                                radius: 2
                                                color: clHighlight
                                                opacity: 0.7
                                            }

                                            MouseArea {
                                                id: groupHeaderMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: groupExpanded = !groupExpanded
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 6
                                                spacing: 6

                                                Text {
                                                    text: groupExpanded ? "📂" : "📁"
                                                    font.pixelSize: 14
                                                }

                                                TextField {
                                                    id: groupNameField
                                                    Layout.fillWidth: true
                                                    text: group.name
                                                    color: whiteText
                                                    font.bold: true
                                                    font.pixelSize: 12
                                                    background: Rectangle { color: "transparent" }
                                                    selectByMouse: true
                                                    readOnly: true
                                                    onEditingFinished: {
                                                        commandStore.updateGroupName(index, text)
                                                        readOnly = true
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        enabled: groupNameField.readOnly
                                                        onClicked: {
                                                            groupNameField.readOnly = false
                                                            groupNameField.forceActiveFocus()
                                                            groupNameField.selectAll()
                                                        }
                                                    }
                                                }

                                                Button {
                                                    text: "＋"
                                                    flat: true
                                                    font.pixelSize: 14
                                                    contentItem: Text {
                                                        text: parent.text
                                                        color: clHighlight
                                                        font: parent.font
                                                    }
                                                    background: Rectangle { color: "transparent" }
                                                    onClicked: commandStore.addCommand(index, "新指令", "", false)
                                                }

                                                Button {
                                                    text: "✕"
                                                    flat: true
                                                    font.pixelSize: 13
                                                    contentItem: Text {
                                                        text: parent.text
                                                        color: clAccent
                                                        font: parent.font
                                                    }
                                                    background: Rectangle { color: "transparent" }
                                                    onClicked: {
                                                        deleteType = "group"
                                                        targetGroupIdx = index
                                                        targetCmdIdx = -1
                                                        deleteConfirmOverlay.visible = true
                                                    }
                                                }
                                            }
                                        }

                                        // Commands under this group
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            visible: groupExpanded
                                            spacing: 4

                                            Repeater {
                                                model: group.commands

                                                delegate: Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 65
                                                    radius: 10
                                                    color: isDark ? "#2b2d30" : "#FFFFFF"
                                                    border.color: cmdMouse.containsMouse
                                                                  ? clHighlight
                                                                  : (isDark ? "#333537" : "#DEE2E6")
                                                    border.width: cmdMouse.containsMouse ? 1 : (isDark ? 0 : 1)

                                                    property int cmdIdx: index
                                                    property string mapKey: index + ":" + cmdIdx
                                                    property bool isHexMode: modelData.isHex || false

                                                    MouseArea {
                                                        id: cmdMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        acceptedButtons: Qt.NoButton
                                                    }

                                                    // Top row: checkbox + name + send + delete
                                                    RowLayout {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.top: parent.top
                                                        anchors.leftMargin: 6
                                                        anchors.rightMargin: 6
                                                        anchors.topMargin: 2
                                                        spacing: 4

                                                        CheckBox {
                                                            id: cmdCheck
                                                            checked: checkedMap[mapKey] === true
                                                            Layout.preferredWidth: 28
                                                            onToggled: {
                                                                var m = Object.assign({}, checkedMap)
                                                                if (checked) m[mapKey] = true
                                                                else delete m[mapKey]
                                                                checkedMap = m
                                                            }
                                                        }

                                                        TextField {
                                                            id: cmdNameField
                                                            Layout.fillWidth: true
                                                            Layout.preferredWidth: 80
                                                            text: modelData.name
                                                            color: whiteText
                                                            font.bold: true
                                                            font.pixelSize: 11
                                                            padding: 2
                                                            background: Rectangle {
                                                                radius: 3
                                                                color: cmdNameField.activeFocus ? clInput : "transparent"
                                                                border.color: cmdNameField.activeFocus ? clHighlight : "transparent"
                                                                border.width: cmdNameField.activeFocus ? 1 : 0
                                                            }
                                                            selectByMouse: true
                                                            onEditingFinished: commandStore.updateCommand(index, cmdIdx, text, modelData.payload)
                                                        }

                                                        Button {
                                                            text: "🚀"
                                                            flat: true
                                                            font.pixelSize: 13
                                                            Layout.preferredWidth: 28
                                                            Layout.preferredHeight: 26
                                                            contentItem: Text {
                                                                text: parent.text
                                                                font: parent.font
                                                                horizontalAlignment: Text.AlignHCenter
                                                                verticalAlignment: Text.AlignVCenter
                                                            }
                                                            background: Rectangle {
                                                                radius: 5
                                                                color: parent.hovered ? (isDark ? "#45484b" : "#E8F0FE") : "transparent"
                                                            }
                                                            onClicked: window.sendCommand(modelData.payload, modelData.isHex || false)
                                                        }

                                                        Button {
                                                            text: "✕"
                                                            flat: true
                                                            font.pixelSize: 12
                                                            Layout.preferredWidth: 24
                                                            Layout.preferredHeight: 26
                                                            contentItem: Text {
                                                                text: parent.text
                                                                color: parent.hovered ? "#FF6B6B" : clAccent
                                                                font: parent.font
                                                                horizontalAlignment: Text.AlignHCenter
                                                                verticalAlignment: Text.AlignVCenter
                                                            }
                                                            background: Rectangle {
                                                                radius: 5
                                                                color: parent.hovered ? (isDark ? "#3a2020" : "#FFE8E8") : "transparent"
                                                            }
                                                            onClicked: {
                                                                deleteType = "command"
                                                                targetGroupIdx = index
                                                                targetCmdIdx = cmdIdx
                                                                deleteConfirmOverlay.visible = true
                                                            }
                                                        }
                                                    }

                                                    // Bottom row: payload + hex/txt badge
                                                    RowLayout {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.bottom: parent.bottom
                                                        anchors.leftMargin: 36
                                                        anchors.rightMargin: 8
                                                        anchors.bottomMargin: 4
                                                        spacing: 4

                                                        TextField {
                                                            Layout.fillWidth: true
                                                            height: 22
                                                            text: modelData.payload
                                                            color: clText
                                                            font.family: "Consolas"
                                                            font.pixelSize: 10
                                                            padding: 4
                                                            background: Rectangle {
                                                                radius: 4
                                                                color: clInput
                                                            }
                                                            selectByMouse: true
                                                            placeholderText: "payload..."
                                                            placeholderTextColor: grayPlaceholder
                                                            onEditingFinished: commandStore.updateCommand(index, cmdIdx, modelData.name, text)
                                                        }

                                                        // Hex/Txt indicator badge
                                                        Rectangle {
                                                            Layout.preferredWidth: 30
                                                            Layout.preferredHeight: 18
                                                            radius: 4
                                                            color: isHexMode ? (isDark ? "#2a3a5a" : "#E0ECFF") : (isDark ? "#2a4a2a" : "#E0FFE0")
                                                            border.color: isHexMode ? clHighlight : "#4CAF50"
                                                            border.width: 1

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: isHexMode ? "HEX" : "TXT"
                                                                font.pixelSize: 8
                                                                font.bold: true
                                                                color: isHexMode ? clHighlight : "#4CAF50"
                                                            }

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    var newHex = !isHexMode
                                                                    commandStore.updateCommand(index, cmdIdx, modelData.name, modelData.payload)
                                                                    // Toggle isHex if supported
                                                                    if (commandStore.setCommandHex)
                                                                        commandStore.setCommandHex(index, cmdIdx, newHex)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Empty state
                                    Text {
                                        anchors.centerIn: parent
                                        visible: commandStore.groups.length === 0
                                        text: "暂无指令分组\n点击「＋分组」添加"
                                        color: grayPlaceholder
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                // Bottom Bar
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Button {
                                        Layout.fillWidth: true
                                        text: "▶ 循环发送"
                                        font.pixelSize: 11
                                        contentItem: Text {
                                            text: parent.text
                                            color: clHighlight
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        background: Rectangle {
                                            color: loopBtnMouse.containsMouse ? (isDark ? "#2a3a5a" : "#E8F0FE") : "transparent"
                                            radius: 8
                                            border.color: clHighlight
                                            border.width: 1
                                            MouseArea { id: loopBtnMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                        }
                                        onClicked: startLoopSend()
                                    }

                                    Button {
                                        text: "导入"
                                        flat: true
                                        font.pixelSize: 11
                                        contentItem: Text {
                                            text: parent.text
                                            color: clText
                                            font.pixelSize: 11
                                        }
                                        background: Rectangle {
                                            color: importBtnMouse.containsMouse ? (isDark ? "#3a3d40" : "#E8EAED") : "transparent"
                                            radius: 6
                                            border.color: clBorder
                                            border.width: 1
                                            MouseArea { id: importBtnMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                        }
                                        onClicked: importFileDialog.open()
                                    }

                                    Button {
                                        text: "导出"
                                        flat: true
                                        font.pixelSize: 11
                                        contentItem: Text {
                                            text: parent.text
                                            color: clText
                                            font.pixelSize: 11
                                        }
                                        background: Rectangle {
                                            color: exportBtnMouse.containsMouse ? (isDark ? "#3a3d40" : "#E8EAED") : "transparent"
                                            radius: 6
                                            border.color: clBorder
                                            border.width: 1
                                            MouseArea { id: exportBtnMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                        }
                                        onClicked: exportFileDialog.open()
                                    }
                                }
                            }

                            // Tab 1: 码表 (Code Table + Converter)
                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentHeight: codeTableColumn.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.VerticalFlick

                                ColumnLayout {
                                    id: codeTableColumn
                                    spacing: 8
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                Text {
                                    text: "码表工具"
                                    color: clHighlight
                                    font.bold: true
                                    font.pixelSize: 15
                                }

                                // 进制转换器
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 180
                                    radius: 10
                                    color: clInput
                                    border.color: clBorder
                                    border.width: 1
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6
                                        Text { text: "进制转换"; color: clText; font.pixelSize: 11; font.bold: true }
                                        TextField {
                                            id: converterInput
                                            Layout.fillWidth: true
                                            placeholderText: "输入数值..."
                                            placeholderTextColor: grayPlaceholder
                                            color: whiteText
                                            font.family: "Consolas"
                                            font.pixelSize: 13
                                            background: Rectangle { color: isDark ? "#2b2d30" : "#FFFFFF"; radius: 6; border.color: converterInput.activeFocus ? clHighlight : clBorder }
                                            selectByMouse: true
                                            onTextChanged: {
                                                var val = parseInt(text)
                                                if (!isNaN(val)) {
                                                    hexOut.text = "0x" + val.toString(16).toUpperCase()
                                                    decOut.text = val.toString()
                                                    octOut.text = "0o" + val.toString(8)
                                                    binOut.text = "0b" + val.toString(2)
                                                } else {
                                                    hexOut.text = "-"; decOut.text = "-"; octOut.text = "-"; binOut.text = "-"
                                                }
                                            }
                                        }
                                        GridLayout {
                                            columns: 2; columnSpacing: 8; rowSpacing: 4
                                            Layout.fillWidth: true
                                            Text { text: "HEX"; color: clHighlight; font.pixelSize: 10; font.bold: true }
                                            Text { id: hexOut; text: "-"; color: whiteText; font.pixelSize: 11; font.family: "Consolas"; Layout.fillWidth: true }
                                            Text { text: "DEC"; color: clHighlight; font.pixelSize: 10; font.bold: true }
                                            Text { id: decOut; text: "-"; color: whiteText; font.pixelSize: 11; font.family: "Consolas"; Layout.fillWidth: true }
                                            Text { text: "OCT"; color: clHighlight; font.pixelSize: 10; font.bold: true }
                                            Text { id: octOut; text: "-"; color: whiteText; font.pixelSize: 11; font.family: "Consolas"; Layout.fillWidth: true }
                                            Text { text: "BIN"; color: clHighlight; font.pixelSize: 10; font.bold: true }
                                            Text { id: binOut; text: "-"; color: whiteText; font.pixelSize: 11; font.family: "Consolas"; Layout.fillWidth: true; wrapMode: Text.Wrap }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: clBorder; opacity: 0.3 }

                                // ASCII码表
                                Text { text: "ASCII 码表"; color: clText; font.pixelSize: 11; font.bold: true }
                                ListView {
                                    Layout.fillWidth: true
                                    height: 128 * 22
                                    clip: true
                                    spacing: 1
                                    model: 128
                                    delegate: Rectangle {
                                        width: parent ? parent.width : 0
                                        height: 22
                                        color: index % 2 === 0 ? (isDark ? "#2b2d30" : "#F8F9FA") : (isDark ? "#323335" : "#FFFFFF")
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 10
                                            Text { text: index; color: clHighlight; font.pixelSize: 10; font.family: "Consolas"; Layout.preferredWidth: 30 }
                                            Text { text: "0x" + index.toString(16).toUpperCase().padStart(2, '0'); color: "#888"; font.pixelSize: 10; font.family: "Consolas"; Layout.preferredWidth: 35 }
                                            Text {
                                                text: {
                                                    if (index < 32) return ["NUL","SOH","STX","ETX","EOT","ENQ","ACK","BEL","BS","HT","LF","VT","FF","CR","SO","SI","DLE","DC1","DC2","DC3","DC4","NAK","SYN","ETB","CAN","EM","SUB","ESC","FS","GS","RS","US"][index]
                                                    if (index === 32) return "SPACE"
                                                    if (index === 127) return "DEL"
                                                    return String.fromCharCode(index)
                                                }
                                                color: whiteText; font.pixelSize: 10; font.family: "Consolas"
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text { text: index >= 32 && index < 127 ? String.fromCharCode(index) : ""; color: clText; font.pixelSize: 10 }
                                        }
                                    }
                                }
                            }
                            }

                            // Tab 2: 设置 (Settings)
                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentHeight: settingsColumn.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.VerticalFlick

                                ColumnLayout {
                                    id: settingsColumn
                                    spacing: 10
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                Text {
                                    text: "设置"
                                    color: clHighlight
                                    font.bold: true
                                    font.pixelSize: 15
                                }

                                // 行尾模式
                                ColumnLayout {
                                    spacing: 6
                                    Layout.fillWidth: true
                                    Text { text: "行尾模式"; color: clText; font.pixelSize: 11; font.bold: true }
                                    RowLayout {
                                        spacing: 4
                                        Layout.fillWidth: true
                                        Repeater {
                                            model: ["无", "LF", "CR", "CRLF"]
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 32
                                                radius: 8
                                                color: settingsStore.lineEndingMode === index ? clHighlight : (leMouse.containsMouse ? (isDark ? "#3a3d40" : "#E8EAED") : clInput)
                                                border.color: settingsStore.lineEndingMode === index ? clHighlight : clBorder
                                                border.width: settingsStore.lineEndingMode === index ? 1 : 0
                                                Text {
                                                    text: modelData
                                                    anchors.centerIn: parent
                                                    color: settingsStore.lineEndingMode === index ? "white" : clText
                                                    font.pixelSize: 11
                                                    font.bold: settingsStore.lineEndingMode === index
                                                }
                                                MouseArea {
                                                    id: leMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: settingsStore.lineEndingMode = index
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: clBorder; opacity: 0.3 }

                                // 数据编码
                                ColumnLayout {
                                    spacing: 6
                                    Layout.fillWidth: true
                                    Text { text: "数据编码"; color: clText; font.pixelSize: 11; font.bold: true }
                                    ComboBox {
                                        id: encodingCombo
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        model: ["UTF-8", "GBK", "GB2312", "ASCII", "ISO-8859-1"]
                                        currentIndex: {
                                            var idx = model.indexOf(settingsStore.dataEncoding)
                                            return idx >= 0 ? idx : 0
                                        }
                                        onCurrentTextChanged: settingsStore.dataEncoding = currentText
                                        background: Rectangle { color: clInput; radius: 8; border.color: encodingCombo.activeFocus ? clHighlight : clBorder }
                                        contentItem: Text { text: encodingCombo.currentText; color: whiteText; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; leftPadding: 12 }
                                        popup: Popup {
                                            y: encodingCombo.height + 3; width: encodingCombo.width; implicitHeight: contentItem.implicitHeight; padding: 5
                                            contentItem: ListView { clip: true; implicitHeight: contentHeight; model: encodingCombo.popup.visible ? encodingCombo.delegateModel : null }
                                            background: Rectangle { color: clCard; radius: 10; border.color: clBorder; border.width: 1 }
                                        }
                                        delegate: ItemDelegate {
                                            width: encodingCombo.width; height: 32
                                            contentItem: Text { text: modelData; color: highlighted ? "white" : whiteText; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; leftPadding: 12 }
                                            background: Rectangle { color: highlighted ? clHighlight : "transparent"; radius: 6 }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: clBorder; opacity: 0.3 }

                                // 串口参数 (只读显示)
                                ColumnLayout {
                                    spacing: 6
                                    Layout.fillWidth: true
                                    Text { text: "串口参数"; color: clText; font.pixelSize: 11; font.bold: true }
                                    GridLayout {
                                        columns: 2
                                        columnSpacing: 12
                                        rowSpacing: 6
                                        Layout.fillWidth: true
                                        Text { text: "数据位"; color: "#888"; font.pixelSize: 11 }
                                        Text { text: "8"; color: whiteText; font.pixelSize: 12; font.family: "Consolas" }
                                        Text { text: "停止位"; color: "#888"; font.pixelSize: 11 }
                                        Text { text: "1"; color: whiteText; font.pixelSize: 12; font.family: "Consolas" }
                                        Text { text: "校验位"; color: "#888"; font.pixelSize: 11 }
                                        Text { text: "None"; color: whiteText; font.pixelSize: 12; font.family: "Consolas" }
                                        Text { text: "流控"; color: "#888"; font.pixelSize: 11 }
                                        Text { text: "None"; color: whiteText; font.pixelSize: 12; font.family: "Consolas" }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: clBorder; opacity: 0.3 }

                                // 十进制模式
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "启用十进制显示模式"; color: clText; font.pixelSize: 12; Layout.fillWidth: true }
                                    Rectangle {
                                        width: 44; height: 24; radius: 12
                                        color: settingsStore.hasDecimalMode ? clHighlight : (isDark ? "#555" : "#CCC")
                                        Rectangle {
                                            width: 20; height: 20; radius: 10
                                            color: "white"
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: settingsStore.hasDecimalMode ? parent.width - 22 : 2
                                            Behavior on x { NumberAnimation { duration: 150 } }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: settingsStore.hasDecimalMode = !settingsStore.hasDecimalMode
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                            }
                        }
                    }

                    // Activity Bar (fixed on right edge)
                    Rectangle {
                        id: activityBar
                        width: 50
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        color: isDark ? "#252628" : "#E8EAED"
                        radius: 12

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            spacing: 4

                            Repeater {
                                id: activityRepeater
                                model: [
                                    { icon: "📋", label: "指令" },
                                    { icon: "📊", label: "码表" },
                                    { icon: "⚙️", label: "设置" }
                                ]
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48
                                    radius: 8
                                    color: activePanel === index ? (isDark ? Qt.rgba(53/255, 116/255, 240/255, 0.2) : Qt.rgba(53/255, 116/255, 240/255, 0.15)) : (actDelegateMouseArea.containsMouse ? (isDark ? Qt.rgba(1,1,1,0.05) : Qt.rgba(0,0,0,0.05)) : "transparent")
                                    border.color: activePanel === index ? clHighlight : "transparent"
                                    border.width: activePanel === index ? 1 : 0

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Text {
                                            text: modelData.icon
                                            font.pixelSize: 18
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: modelData.label
                                            font.pixelSize: 9
                                            color: activePanel === index ? clHighlight : clText
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: actDelegateMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (activePanel === index) {
                                                activePanel = -1
                                            } else {
                                                activePanel = index
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"

                Flickable {
                    anchors.fill: parent
                    contentHeight: sysInfoColumn.implicitHeight + 40
                    clip: true

                    ColumnLayout {
                        id: sysInfoColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 20
                        spacing: 25

                        // 应用信息卡片
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 180
                            color: clCard
                            radius: 15
                            border.color: clBorder
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 25
                                spacing: 15
                                RowLayout {
                                    spacing: 20
                                    Rectangle {
                                        width: 60; height: 60; radius: 12
                                        color: clHighlight
                                        Text { text: "G"; color: "white"; font.bold: true; font.pixelSize: 32; anchors.centerIn: parent }
                                    }
                                    ColumnLayout {
                                        Text { text: "MySerial Gemini"; color: whiteText; font.bold: true; font.pixelSize: 22 }
                                        Text { text: "v0.1.0 Alpha Build"; color: clText; font.pixelSize: 13 }
                                    }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: clBorder; opacity: 0.5 }
                                Text { 
                                    text: "一款基于 Qt 6 开发的现代化串口调试助手，支持双模式显示及智能校验。"
                                    color: clText; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.Wrap
                                }
                            }
                        }

                        // 环境与支持
                        RowLayout {
                            spacing: 20
                            Layout.fillWidth: true

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 220
                                color: clCard
                                radius: 15
                                border.color: clBorder
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 20; spacing: 12
                                    Text { text: "运行环境"; color: clHighlight; font.bold: true; font.pixelSize: 14 }
                                    ListModel {
                                        id: envModel
                                        ListElement { k: "Qt Framework"; v: "6.11.0" }
                                        ListElement { k: "Compiler"; v: "MinGW 64-bit" }
                                        ListElement { k: "Platform"; v: "Windows 10/11" }
                                        ListElement { k: "Build Date"; v: "2026-04-21" }
                                    }
                                    Repeater {
                                        model: envModel
                                        RowLayout {
                                            Text { text: model.k; color: "#888"; font.pixelSize: 12; Layout.preferredWidth: 100 }
                                            Text { text: model.v; color: whiteText; font.pixelSize: 12; font.family: "Consolas" }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 220
                                color: clCard
                                radius: 15
                                border.color: clBorder
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 20; spacing: 12
                                    Text { text: "技术支持"; color: clHighlight; font.bold: true; font.pixelSize: 14 }
                                    Text { 
                                        text: "如果您在使用过程中遇到任何问题或有改进建议，请通过邮件联系开发者。"
                                        color: clText; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.Wrap
                                    }
                                    Item { Layout.fillHeight: true }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 45; radius: 10; color: clInput
                                        RowLayout {
                                            anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 15
                                            Text { text: "📧"; font.pixelSize: 16 }
                                            Text { text: "mmooka001@gmail.com"; color: whiteText; font.pixelSize: 13; font.bold: true }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "复制"; color: clHighlight; font.pixelSize: 11; MouseArea { anchors.fill: parent; onClicked: { /* TODO: Clipboard copy */ } } }
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
                        Button { 
                            text: "取消"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            background: Rectangle { 
                                anchors.fill: parent
                                radius: 10
                                color: parent.hovered ? "#444" : "#333" 
                            }
                            contentItem: Text { 
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: { deleteConfirmOverlay.visible = false } 
                        }
                        Button { 
                            text: "确定删除"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            background: Rectangle { 
                                anchors.fill: parent
                                radius: 10
                                color: parent.hovered ? Qt.lighter(clAccent, 1.1) : clAccent 
                            }
                            contentItem: Text { 
                                text: parent.text
                                color: "white"
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: { 
                                if (deleteType === "group") { commandStore.deleteGroup(targetGroupIdx) } 
                                else if (deleteType === "cmd") { commandStore.deleteCommand(targetGroupIdx, targetCmdIdx) } 
                                deleteConfirmOverlay.visible = false 
                            } 
                        }
                    }
                }
            }
        }

        // FileDialogs for import/export
        FileDialog {
            id: importFileDialog
            title: "导入指令预设"
            nameFilters: ["JSON files (*.json)", "All files (*)"]
            fileMode: FileDialog.OpenFile
            onAccepted: commandStore.importFromFile(selectedFile.toString().replace("file:///", ""))
        }
        FileDialog {
            id: exportFileDialog
            title: "导出指令预设"
            nameFilters: ["JSON files (*.json)", "All files (*)"]
            fileMode: FileDialog.SaveFile
            onAccepted: commandStore.exportToFile(selectedFile.toString().replace("file:///", ""))
        }

        Rectangle {
            id: statusBar
            width: parent.width
            height: 28
            color: clHeader
            anchors.bottom: parent.bottom
            z: 100

            Rectangle {
                width: parent.width
                height: 1
                color: clBorder
                anchors.top: parent.top
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 15

                RowLayout {
                    spacing: 8
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: serialManager.isOpen ? "#4CAF50" : "#F44336"
                    }
                    Text {
                        text: serialManager.isOpen ? "已连接" : "未连接"
                        color: clText
                        font.pixelSize: 11
                    }
                }

                // RX/TX counters
                RowLayout {
                    spacing: 12
                    visible: serialManager.isOpen
                    Text {
                        text: "▼ RX: " + recordStore.rxCount + " B"
                        color: "#4CAF50"
                        font.pixelSize: 10
                        font.family: "Consolas"
                    }
                    Text {
                        text: "▲ TX: " + recordStore.txCount + " B"
                        color: clHighlight
                        font.pixelSize: 10
                        font.family: "Consolas"
                    }
                }

                Item { Layout.fillWidth: true }

                // Record count + Export
                RowLayout {
                    spacing: 8
                    Text {
                        text: "记录: " + recordStore.records.length
                        color: clText
                        font.pixelSize: 10
                        opacity: 0.7
                    }
                    Rectangle {
                        width: 42; height: 20; radius: 4
                        color: exportMouse.containsMouse ? (isDark ? "#3e4043" : "#E8EAED") : "transparent"
                        Text {
                            text: "导出"
                            anchors.centerIn: parent
                            color: clHighlight
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: exportMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: exportRecordDialog.open()
                        }
                    }
                    Rectangle {
                        width: 42; height: 20; radius: 4
                        color: clearRecMouse.containsMouse ? (isDark ? "#3e4043" : "#E8EAED") : "transparent"
                        Text {
                            text: "清空"
                            anchors.centerIn: parent
                            color: "#888"
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: clearRecMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                recordStore.clearRecords()
                                terminalModel.clear()
                            }
                        }
                    }
                }

                Text {
                    text: "Support: mmooka001@gmail.com"
                    color: clText
                    font.pixelSize: 11
                    opacity: 0.8
                }
            }
        }

        // Export record dialog
        FileDialog {
            id: exportRecordDialog
            title: "导出通信记录"
            nameFilters: ["JSON files (*.json)", "CSV files (*.csv)", "All files (*)"]
            fileMode: FileDialog.SaveFile
            onAccepted: recordStore.exportRecords(selectedFile.toString())
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
            if (autoScroll) {
                terminalView.positionViewAtEnd()
            }
        }
    }

    // Sync line ending mode from settingsStore to serialManager
    Connections {
        target: settingsStore
        function onLineEndingModeChanged() {
            serialManager.lineEndingMode = settingsStore.lineEndingMode
        }
        function onCustomLineEndingChanged() {
            // Custom line ending support can be added later
        }
    }

    // Initialize line ending mode on startup
    Component.onCompleted: {
        serialManager.lineEndingMode = settingsStore.lineEndingMode
    }
}
