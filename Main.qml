import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MySerial_Gemini
import com.gemini.serial
import QtQuick.Dialogs
import QtCore

Window {
    id: window
    width: 1250
    height: 850
    minimumWidth: 700
    minimumHeight: 550
    visible: true

    // 窗口过窄时自动收起右侧功能面板与连接配置抽屉，避免中间区被压缩、面板被挤出屏幕。
    // layoutReady 防止初始化阶段 width 从 0 增长时误触发
    property bool layoutReady: false
    onWidthChanged: {
        if (!layoutReady) return
        if (sidePanel >= 0 && width < 780) sidePanel = -1
    }
    title: qsTr("MySerial Gemini")
    color: "transparent"
    property bool stayOnTop: false
    flags: Qt.Window | Qt.FramelessWindowHint | (stayOnTop ? Qt.WindowStaysOnTopHint : 0)

    readonly property bool isNarrow: width < 1100
    readonly property bool isUltraNarrow: width < 900
    readonly property bool edgeToEdge: visibility === Window.Maximized || visibility === Window.FullScreen

    property int themeMode: settingsStore.themeMode
    readonly property bool isDark: appTheme.dark

    // 磨砂层染色随主题切换（深色=暗 tint，浅色=白 tint）
    function updateAcrylicTint() {
        var tint = isDark ? appTheme.workspace : appTheme.surface
        acrylic.setTint(tint.r, tint.g, tint.b, isDark ? 0.55 : 0.65)
    }
    onIsDarkChanged: if (layoutReady) updateAcrylicTint()

    AppTheme {
        id: appTheme
        mode: window.themeMode
        style: settingsStore.colorStyle
        appearance: settingsStore.appearanceMode
        customAccent: settingsStore.customAccent
        customAccentEnabled: settingsStore.useCustomAccent
    }
    Connections {
        target: appTheme
        function onSurfaceChanged() { if (layoutReady) updateAcrylicTint() }
    }
    readonly property var themeNames: appTheme.names
    readonly property color clCard: appTheme.surface
    readonly property color clInput: appTheme.block
    readonly property color clHeader: appTheme.alpha(appTheme.raised, 0.35)
    readonly property color clText: appTheme.secondary
    readonly property color clHighlight: appTheme.primary
    readonly property color clBorder: appTheme.line
    readonly property color whiteText: appTheme.text
    readonly property color grayPlaceholder: appTheme.muted
    readonly property color clWorkspace: appTheme.workspace
    readonly property color clToolSurface: appTheme.surface
    readonly property color clCanvas: appTheme.surface
    readonly property color clSurfaceLine: appTheme.line
    // 左侧面板统一状态：-1=全关 0=连接 1=指令 2=码表 3=设置（互斥）
    property int sidePanel: 0
    property int sidePanelWidth: settingsStore.sidePanelWidth
    property bool sidePanelDragActive: false
    property int clickOffset: 0           // Click animation offset

    // Layout constants
    readonly property int panelGap: 12
    readonly property int moduleRadius: 14
    readonly property int leftRailWidth: 56
    readonly property int minimumCenterWidth: 200

    // Clamp panels so center never collapses
    readonly property int maxSidePanelWidth: Math.max(200, bodyBg.width - panelGap * 3 - minimumCenterWidth)
    readonly property int collapsePanelWidth: 180
    readonly property int effectiveSidePanelWidth: Math.max(collapsePanelWidth, Math.min(sidePanelWidth, maxSidePanelWidth))
    property int sendPanelHeight: 180
    readonly property int minSendPanelHeight: 160
    readonly property int minTerminalHeight: 160
    readonly property int terminalSendGap: 15
    readonly property int maxSendPanelHeight: Math.max(minSendPanelHeight, centerColumn.height - minTerminalHeight - terminalSendResizeHandle.height)

    // 阈值包含控件实际宽度、左右内边距和行间距，避免窄窗口把控件裁成半截。
    readonly property bool showChecksumControl: sendCard.width >= 550
    readonly property bool showAutoControl: sendCard.width >= 450 || autoSending
    readonly property bool showTimeControl: sendCard.width >= (autoSending ? 449 : 385)
    readonly property bool showTxModeControl: sendCard.width >= (autoSending ? 374 : 310)
    readonly property bool showRxModeControl: sendCard.width >= (autoSending ? 264 : 200)
    property bool globalRxHex: true 
    property alias globalTxHex: inputSender.hexMode
    property bool globalTimestamp: true
    property int currentPageIndex: 0
    property bool autoScroll: true
    property string checksumValue: ChecksumHelper.hexChecksumPreview(sendInput.text, globalTxHex, checksumCombo.currentIndex)

    function exportTimestamp() {
        return Qt.formatDateTime(new Date(), "yyyyMMddhhmmss")
    }

    function commandExportFileName() {
        return "指令 " + exportTimestamp() + ".json"
    }

    function recordExportFileName() {
        return "对话记录 " + exportTimestamp() + ".csv"
    }

    function fileUrlFromLocalPath(path) {
        var normalized = String(path).replace(/\\/g, "/")
        if (normalized.indexOf("file:/") === 0)
            return normalized
        if (normalized.charAt(0) === "/")
            return "file://" + normalized
        return "file:///" + normalized
    }

    function defaultExportFileUrl(fileName) {
        return fileUrlFromLocalPath(StandardPaths.writableLocation(StandardPaths.DocumentsLocation) + "/" + fileName)
    }

    // Send history
    property var sendHistory: []
    property int historyIndex: -1  // -1 = current input, 0+ = history position

    readonly property bool autoSending: inputSender.running
    property alias sendInterval: inputSender.interval

    // 指令循环持有自己的队列、间隔和运行状态。
    property var loopCmds: []
    property int loopIndex: -1
    property bool loopSending: false
    property int loopInterval: 500
    property var portList: []

    function refreshPorts() {
        portList = serialManager.availablePorts()
    }

    SendController {
        id: inputSender
        backend: serialManager
        inputText: sendInput.text
        checksumType: checksumCombo.currentIndex
        onInputConverted: (hex) => sendInput.text = hex
    }

    Timer {
        id: startupPortRefreshTimer
        interval: 200
        repeat: false
        onTriggered: refreshPorts()
    }

    Timer {
        id: loopTimer
        interval: loopInterval
        repeat: false
        onTriggered: {
            if (!loopSending || loopCmds.length === 0) {
                loopSending = false
                loopIndex = -1
                return
            }
            var cmd = loopCmds[loopIndex]
            window.sendCommand(cmd.payload, cmd.isHex)
            loopIndex++
            if (loopIndex >= loopCmds.length) loopIndex = 0  // loop forever
            if (loopSending) loopTimer.start()
        }
    }

    function startLoopSend() {
        if (loopSending) return
        if (!serialManager.isOpen) { inputSender.notice = "请先连接串口。"; return }
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
        if (cmds.length === 0) { inputSender.notice = "请先勾选要循环发送的指令。"; return }
        inputSender.notice = ""
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
        return inputSender.sendPreset(payload, isHex)
    }

    function doSend() {
        if (!inputSender.sendOnce()) return
        // Record to history
        var h = sendHistory.slice()
        h.unshift(sendInput.text)
        if (h.length > 50) h.pop()
        sendHistory = h
        historyIndex = -1

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

    component SidePanelHeading: Text {
        Layout.preferredHeight: 32
        verticalAlignment: Text.AlignVCenter
        color: window.whiteText
        font.bold: true
        font.pixelSize: 15
    }

    component UiButton: ActionButton {
        theme: appTheme
    }

    component ModeSwitch: SegmentedControl {
        theme: appTheme
    }

    component IntervalControl: IntervalField { theme: appTheme }

    component ConfigComboBox: GlassComboBox {
        backdropItem: sidePanelCard
        dark: window.isDark
        textColor: window.whiteText
        secondaryTextColor: window.clText
        inputColor: window.clInput
        surfaceColor: window.clCard
        outlineColor: window.clBorder
        accentColor: window.clHighlight
    }

    Rectangle {
        id: shellBackdrop
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: appTheme.shellStart }
            GradientStop { position: 1.0; color: appTheme.shellEnd }
        }
    }

    Item {
        id: rootRect
        anchors.fill: parent
        clip: true

        FocusDismissLayer { focusRoot: rootRect }

        Rectangle {
            id: leftRail
            z: 200
            width: leftRailWidth
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: "transparent"

            // 软件图标的单色轮廓版，按可见图形的光学中心对齐。
            Item {
                width: parent.width
                height: titleBar.height
                SerialLogo {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    strokeColor: window.whiteText
                }
            }

            Item {
                id: railNavigation
                x: 0
                y: bodyBg.y + 12
                width: parent.width
                height: 4 * 48 + 3 * 4

                Column {
                    id: railButtons
                    z: 1
                    width: parent.width
                    spacing: 4

                    Repeater {
                        id: railRepeater
                        model: [
                            { symbol: "\uE839", label: "连接" },
                            { symbol: "\uE8A5", label: "指令" },
                            { symbol: "\uE9D9", label: "码表" },
                            { symbol: "\uE713", label: "设置" }
                        ]
                        delegate: Item {
                            id: railButton
                            required property int index
                            required property var modelData
                            width: railButtons.width
                            height: 48
                            readonly property bool selected: sidePanel === index

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                anchors.topMargin: 2
                                anchors.bottomMargin: 2
                                radius: 14
                                color: isDark ? "#ffffff" : "#000000"
                                opacity: railMouse.containsMouse && !railButton.selected ? 0.055 : 0
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }

                            Item {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 34
                                scale: railMouse.pressed ? 0.94 : 1
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                Text {
                                    width: parent.width
                                    height: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: railButton.modelData.symbol
                                    font.family: "Segoe Fluent Icons"
                                    font.pixelSize: 19
                                    color: railButton.selected ? clHighlight : clText
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                                Text {
                                    y: 23
                                    width: parent.width
                                    height: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: railButton.modelData.label
                                    font.pixelSize: 9
                                    color: railButton.selected ? clHighlight : clText
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                            }

                            MouseArea {
                                id: railMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    sidePanel = railButton.selected ? -1 : railButton.index
                                    if (sidePanel >= 0 && currentPageIndex !== 0)
                                        currentPageIndex = 0
                                }
                            }
                        }
                    }
                }

                LiquidGlassSelection {
                    anchors.fill: parent
                    sourceItem: shellBackdrop
                    sourceRect: {
                        var origin = railNavigation.mapToItem(shellBackdrop, 0, 0)
                        return Qt.rect(origin.x, origin.y, width, height)
                    }
                    baseColor: window.clToolSurface
                    selectedIndex: sidePanel
                    selectedItem: sidePanel >= 0 && railRepeater.count > sidePanel
                                  ? railRepeater.itemAt(sidePanel) : null
                    dark: isDark
                }
            }
        }
        // 导航共用 rootRect 的磨砂底层，工作内容收在独立的实色圆角区域中。
        Rectangle {
            id: bodyBg
            anchors.left: leftRail.right
            anchors.top: titleBar.bottom
            anchors.bottom: statusBar.top
            anchors.right: parent.right
            anchors.leftMargin: 0
            anchors.rightMargin: 8
            anchors.topMargin: 6
            anchors.bottomMargin: 4
            color: clWorkspace
            radius: 20
        }

        Rectangle {
            id: titleBar
            width: parent.width
            height: 42
            color: "transparent"
            z: 100
            
            RowLayout {
                anchors.fill: parent
                spacing: 0

                Row {
                    Layout.fillHeight: true
                    Layout.leftMargin: leftRailWidth
                    spacing: 0
                    Repeater {
                        model: ["主控制台", "系统信息"]
                        Rectangle {
                            width: 110
                            height: 42
                            color: "transparent"
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 6
                                anchors.topMargin: 7
                                anchors.bottomMargin: 7
                                radius: 8
                                color: isDark ? Qt.rgba(1, 1, 1, 0.065) : Qt.rgba(0, 0, 0, 0.045)
                                opacity: currentPageIndex === index ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 160 } }
                            }
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
                            if (window.edgeToEdge) {
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
                        color: isDark ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                        readonly property bool isTop: window.stayOnTop
                        contentItem: Text { 
                            text: "\uE718"
                            font.family: "Segoe Fluent Icons"
                            font.pixelSize: 13
                            color: pinBtn.isTop ? clHighlight : (pinBtn.hovered ? whiteText : clText)
                            opacity: pinBtn.isTop ? 1.0 : (pinBtn.hovered ? 0.9 : 0.3)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter 
                        }
                        background: Rectangle { 
                            anchors.fill: parent
                            anchors.margins: 4
                            color: pinBtn.hovered ? (isDark ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.06)) : "transparent"
                            radius: 8
                        }
                        onClicked: {
                            window.stayOnTop = !window.stayOnTop
                        }
                    }

                    Button {
                        id: themeBtn
                        width: 40
                        height: 42
                        flat: true
                        padding: 0
                        contentItem: Text { 
                            text: "\uE790"
                            font.family: "Segoe Fluent Icons"
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter 
                            color: themeBtn.hovered ? clHighlight : whiteText
                        }
                        background: Rectangle { 
                            anchors.fill: parent
                            anchors.margins: 4
                            color: themeBtn.hovered ? (isDark ? Qt.rgba(255,255,255,0.08) : Qt.rgba(0,0,0,0.06)) : "transparent"
                            radius: 10
                        }
                        onClicked: {
                            themePopup.opened ? themePopup.close() : themePopup.open()
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
                            color: parent.hovered ? (isDark ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.06)) : "transparent"
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
                            text: window.edgeToEdge ? "\uE923" : "\uE922"
                            font.family: "Segoe Fluent Icons"
                            color: clText
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter 
                        }
                        background: Rectangle { 
                            color: parent.hovered ? (isDark ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.06)) : "transparent"
                            radius: 8
                        }
                        onClicked: {
                            if (window.edgeToEdge) {
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
                            anchors.fill: parent
                            anchors.margins: 4
                            color: parent.hovered ? "#e81123" : "transparent"
                            radius: 8
                        }
                        onClicked: {
                            Qt.quit()
                        }
                    }
                }
            }
        }

        StackLayout {
            anchors.fill: bodyBg
            anchors.margins: 12
            currentIndex: currentPageIndex

            RowLayout {
                spacing: 0

                // ── 左侧面板：连接/指令/码表/设置（四选一互斥）──
                Rectangle {
                    id: sidePanelCard
                    Layout.preferredWidth: sidePanel < 0 ? 0 : effectiveSidePanelWidth
                    Layout.minimumWidth: Layout.preferredWidth
                    Layout.maximumWidth: Layout.preferredWidth
                    Behavior on Layout.preferredWidth { enabled: !sidePanelDragActive; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Layout.fillHeight: true
                    visible: sidePanel >= 0 || width > 1
                    color: clToolSurface
                    radius: moduleRadius
                    border.color: clSurfaceLine
                    clip: true

                    StackLayout {
                        id: sidePanelStack
                        anchors.fill: parent
                        currentIndex: sidePanel < 0 ? 0 : (sidePanel === 0 ? 0 : 1)

                        // Page 0: 连接配置
                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 12
                        contentHeight: configColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: configColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 8
                        
                        SidePanelHeading { text: "连接配置" }

                        ColumnLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            RowLayout {
                                Text { text: "选择端口"
                                 color: appTheme.muted
                                 font.pixelSize: 11
                                 Layout.fillWidth: true }
                                UiButton {
                                    text: "刷新"
                                    glyph: "\uE72C"
                                    Layout.preferredHeight: 26
                                    hint: "重新扫描串口"
                                    onClicked: refreshPorts()
                                }
                            }
                            ConfigComboBox {
                                id: portCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                model: portList
                                textRole: "name"
                                portDetails: true
                                font.pixelSize: 13
                            }
                        }

                        ColumnLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Text { text: "通信波特率"
                             color: appTheme.muted
                             font.pixelSize: 11 }
                            ConfigComboBox {
                                id: baudCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                model: [9600, 19200, 38400, 57600, 115200, 230400, 256000, 460800, 921600, 1000000, 2000000]
                                currentIndex: 4
                                font.pixelSize: 13
                            }
                        }

                        ColumnLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Text { text: "数据位"
                             color: appTheme.muted
                             font.pixelSize: 11 }
                            ConfigComboBox {
                                id: dataBitsCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                model: [5, 6, 7, 8]
                                currentIndex: 3
                            }
                        }

                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "停止位"; color: appTheme.muted; font.pixelSize: 10 }
                                ConfigComboBox {
                                    id: stopBitsCombo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    model: ["1", "1.5", "2"]
                                    currentIndex: 0
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: "校验位"; color: appTheme.muted; font.pixelSize: 10 }
                                ConfigComboBox {
                                    id: parityCombo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    model: ["None", "Odd", "Even", "Mark", "Space"]
                                    currentIndex: 0
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Text { text: "流控制"
                             color: appTheme.muted
                             font.pixelSize: 11 }
                            ConfigComboBox {
                                id: flowCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                model: ["None", "Hardware", "Software"]
                                currentIndex: 0
                            }
                        }

                        UiButton {
                            id: connectBtn
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                             Layout.fillWidth: true
                             Layout.preferredHeight: 45
                             text: serialManager.isOpen ? "断开当前连接" : "建立串口连接"
                            kind: serialManager.isOpen ? "tonal" : "primary"
                            glyph: "\uE839"
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
                        }

                        Item { Layout.fillHeight: true }
                    }
                    } // Flickable

                        // Page 1: 指令/码表/设置
                        StackLayout {
                            id: featurePanelStack
                            anchors.fill: parent
                            anchors.margins: 12
                            currentIndex: sidePanel >= 1 ? sidePanel - 1 : 0

                            // Tab 0: 指令 (Command Presets)
                            ColumnLayout {
                                spacing: 8

                                // Header
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    SidePanelHeading {
                                        text: "指令预设库"
                                    }
                                    Item { Layout.fillWidth: true }
                                    UiButton {
                                        text: "＋分组"
                                        Layout.preferredHeight: 32
                                        font.pixelSize: 12
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
                                        property int groupIndex: index

                                        // Group Header
                                        Rectangle {
                                            id: groupHeaderRect
                                            Layout.fillWidth: true
                                            height: 38
                                            radius: 10
                                            color: groupHeaderMouse.containsMouse ? clInput : clHeader
                                            border.color: clBorder
                                            border.width: 1
                                            clip: true

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
                                                    text: groupExpanded ? "\uE838" : "\uE8B7"
                                                    color: clText
                                                    font.family: "Segoe Fluent Icons"
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
                                                        if (text !== group.name) commandStore.updateGroupName(index, text)
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

                                                UiButton {
                                                    glyph: "\uE710"
                                                    hint: "添加指令"
                                                    Layout.preferredWidth: 28
                                                    Layout.preferredHeight: 28
                                                    onClicked: commandStore.addCommand(index, "新指令", "", false)
                                                }

                                                UiButton {
                                                    glyph: "\uE74D"
                                                    hint: "删除分组"
                                                    kind: "danger"
                                                    Layout.preferredWidth: 28
                                                    Layout.preferredHeight: 28
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
                                            spacing: 2

                                            Repeater {
                                                model: group.commands

                                                delegate: Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 50
                                                    radius: 8
                                                    color: cmdMouse.containsMouse ? clInput : "transparent"
                                                    border.color: cmdMouse.containsMouse ? clHighlight : clBorder
                                                    border.width: 1

                                                    property int groupIdx: parent.parent.groupIndex
                                                    property int cmdIdx: index
                                                    property string mapKey: groupIdx + ":" + cmdIdx
                                                    property bool isHexMode: {
                                                        var g = commandStore.groups
                                                        if (groupIdx >= 0 && groupIdx < g.length) {
                                                            var cmds = g[groupIdx].commands || []
                                                            if (cmdIdx >= 0 && cmdIdx < cmds.length)
                                                                return cmds[cmdIdx].isHex || false
                                                        }
                                                        return false
                                                    }

                                                    MouseArea {
                                                        id: cmdMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        acceptedButtons: Qt.NoButton
                                                    }

                                                    // Checkbox: vertically centered in the whole card
                                                    Item {
                                                        id: checkboxArea
                                                        width: 28
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        anchors.leftMargin: 4

                                                        Rectangle {
                                                            width: 16
                                                            height: 16
                                                            radius: 4
                                                            anchors.centerIn: parent
                                                            color: cmdCheckbox.checked ? clHighlight : clInput
                                                            border.color: cmdCheckbox.checked ? clHighlight : clBorder
                                                            border.width: 1

                                                            Text {
                                                                visible: cmdCheckbox.checked
                                                                anchors.centerIn: parent
                                                                text: "✓"
                                                                color: "white"
                                                                font.pixelSize: 11
                                                                font.bold: true
                                                            }

                                                            MouseArea {
                                                                id: cmdCheckbox
                                                                property bool checked: checkedMap[mapKey] === true
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    var m = Object.assign({}, checkedMap)
                                                                    if (!checked) m[mapKey] = true
                                                                    else delete m[mapKey]
                                                                    checkedMap = m
                                                                }
                                                            }
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        anchors.left: checkboxArea.right
                                                        anchors.right: parent.right
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        anchors.leftMargin: 2
                                                        anchors.rightMargin: 4
                                                        anchors.topMargin: 4
                                                        anchors.bottomMargin: 4
                                                        spacing: 2

                                                        // Row 1: name + HEX/TXT + send + delete
                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 4

                                                            TextField {
                                                                Layout.preferredWidth: parent.width * 0.35
                                                                Layout.fillWidth: true
                                                                text: modelData.name
                                                                color: whiteText
                                                                font.pixelSize: 10
                                                                font.bold: true
                                                                padding: 2
                                                                background: Rectangle {
                                                                    radius: 3
                                                                    color: parent.activeFocus ? clInput : "transparent"
                                                                    border.color: parent.activeFocus ? clHighlight : "transparent"
                                                                    border.width: parent.activeFocus ? 1 : 0
                                                                }
                                                                selectByMouse: true
                                                                onEditingFinished: if (text !== modelData.name) commandStore.updateCommand(groupIdx, cmdIdx, text, modelData.payload)
                                                            }

                                                            // HEX/TXT badge
                                                            UiButton {
                                                                Layout.preferredWidth: 32
                                                                Layout.preferredHeight: 22
                                                                leftPadding: 4
                                                                rightPadding: 4
                                                                text: isHexMode ? "HEX" : "TXT"
                                                                font.pixelSize: 8
                                                                kind: "tonal"
                                                                hint: "切换 TXT / HEX"
                                                                onClicked: commandStore.setCommandHex(groupIdx, cmdIdx, !isHexMode)
                                                            }

                                                            // Send
                                                            UiButton {
                                                                Layout.preferredWidth: 32
                                                                Layout.preferredHeight: 22
                                                                leftPadding: 4
                                                                rightPadding: 4
                                                                text: "发送"
                                                                font.pixelSize: 8
                                                                onClicked: window.sendCommand(modelData.payload, isHexMode)
                                                            }

                                                            // Delete
                                                            UiButton {
                                                                glyph: "\uE74D"
                                                                kind: "danger"
                                                                hint: "删除指令"
                                                                Layout.preferredWidth: 22
                                                                Layout.preferredHeight: 22
                                                                leftPadding: 3
                                                                rightPadding: 3
                                                                onClicked: {
                                                                    deleteType = "command"
                                                                    targetGroupIdx = groupIdx
                                                                    targetCmdIdx = cmdIdx
                                                                    deleteConfirmOverlay.visible = true
                                                                }
                                                            }
                                                        }

                                                        // Row 2: payload (full width, bigger)
                                                        TextField {
                                                            Layout.fillWidth: true
                                                            Layout.fillHeight: true
                                                            text: modelData.payload || ""
                                                            color: clText
                                                            font.family: "Consolas"
                                                            font.pixelSize: 11
                                                            padding: 4
                                                            placeholderText: "payload"
                                                            placeholderTextColor: grayPlaceholder
                                                            background: Rectangle {
                                                                radius: 3
                                                                color: parent.activeFocus ? clInput : clCard
                                                                border.color: parent.activeFocus ? clHighlight : clBorder
                                                                border.width: 1
                                                            }
                                                            selectByMouse: true
                                                            onEditingFinished: if (text !== modelData.payload) commandStore.updateCommand(groupIdx, cmdIdx, modelData.name, text)
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
                                    id: commandBottomBar
                                    Layout.fillWidth: true
                                    spacing: 3
                                    clip: true
                                    property bool showImportExport: width >= 230
                                    property int importExportButtonWidth: showImportExport ? 30 : 0

                                    IntervalControl {
                                        Layout.preferredWidth: 88
                                        Layout.preferredHeight: 28
                                        interval: loopInterval
                                        onIntervalEdited: (milliseconds) => loopInterval = milliseconds
                                    }

                                    UiButton {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 54
                                        Layout.preferredWidth: 80
                                        Layout.preferredHeight: 24
                                        clip: true
                                        text: loopSending ? "停止" : "循环"
                                        font.pixelSize: 10
                                        kind: loopSending ? "danger" : "tonal"
                                        selected: loopSending
                                        leftPadding: 4
                                        rightPadding: 4
                                        onClicked: {
                                            if (loopSending) {
                                                loopSending = false
                                                loopIndex = -1
                                                loopTimer.stop()
                                            } else {
                                                startLoopSend()
                                            }
                                        }
                                    }

                                    UiButton {
                                        Layout.preferredWidth: commandBottomBar.importExportButtonWidth
                                        Layout.minimumWidth: 0
                                        Layout.maximumWidth: 30
                                        Layout.preferredHeight: 24
                                        text: "导入"
                                        kind: "tonal"
                                        clip: true
                                        visible: commandBottomBar.showImportExport
                                        enabled: commandBottomBar.showImportExport
                                        font.pixelSize: 11
                                        leftPadding: 4
                                        rightPadding: 4
                                        onClicked: importFileDialog.open()
                                    }

                                    UiButton {
                                        Layout.preferredWidth: commandBottomBar.importExportButtonWidth
                                        Layout.minimumWidth: 0
                                        Layout.maximumWidth: 30
                                        Layout.preferredHeight: 24
                                        text: "导出"
                                        kind: "tonal"
                                        clip: true
                                        visible: commandBottomBar.showImportExport
                                        enabled: commandBottomBar.showImportExport
                                        font.pixelSize: 11
                                        leftPadding: 4
                                        rightPadding: 4
                                        onClicked: {
                                            exportFileDialog.currentFile = defaultExportFileUrl(commandExportFileName())
                                            exportFileDialog.open()
                                        }
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

                                SidePanelHeading {
                                    text: "码表工具"
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
                                            background: Rectangle { color: clCard; radius: 6; border.color: converterInput.activeFocus ? clHighlight : clBorder }
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
                                            Text { text: "HEX"; color: clText; font.pixelSize: 10; font.bold: true }
                                            Text { id: hexOut; text: "-"; color: whiteText; font.pixelSize: 11; font.family: "Consolas"; Layout.fillWidth: true }
                                            Text { text: "DEC"; color: clText; font.pixelSize: 10; font.bold: true }
                                            Text { id: decOut; text: "-"; color: whiteText; font.pixelSize: 11; font.family: "Consolas"; Layout.fillWidth: true }
                                            Text { text: "OCT"; color: clText; font.pixelSize: 10; font.bold: true }
                                            Text { id: octOut; text: "-"; color: whiteText; font.pixelSize: 11; font.family: "Consolas"; Layout.fillWidth: true }
                                            Text { text: "BIN"; color: clText; font.pixelSize: 10; font.bold: true }
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
                                        color: index % 2 === 0 ? clCard : clInput
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 10
                                            Text { text: index; color: clText; font.pixelSize: 10; font.family: "Consolas"; Layout.preferredWidth: 30 }
                                            Text { text: "0x" + index.toString(16).toUpperCase().padStart(2, '0'); color: appTheme.muted; font.pixelSize: 10; font.family: "Consolas"; Layout.preferredWidth: 35 }
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
                                    spacing: 8
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                SidePanelHeading {
                                    text: "设置"
                                }

                                // 行尾模式
                                ColumnLayout {
                                    spacing: 6
                                    Layout.fillWidth: true
                                    Text { text: "行尾模式"; color: clText; font.pixelSize: 11; font.bold: true }
                                    ModeSwitch {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                        model: ["无", "LF", "CR", "CRLF"]
                                        currentIndex: settingsStore.lineEndingMode
                                        onActivated: (index) => settingsStore.lineEndingMode = index
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: clBorder; opacity: 0.3 }

                                // 数据编码
                                ColumnLayout {
                                    spacing: 6
                                    Layout.fillWidth: true
                                    Text { text: "数据编码"; color: clText; font.pixelSize: 11; font.bold: true }
                                    ConfigComboBox {
                                        id: encodingCombo
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        model: ["UTF-8", "GBK", "GB2312", "ASCII", "ISO-8859-1"]
                                        currentIndex: Math.max(0, model.indexOf(settingsStore.dataEncoding))
                                        onActivated: settingsStore.dataEncoding = currentText
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
                                        Text { text: "数据位"; color: appTheme.muted; font.pixelSize: 11 }
                                        Text { text: "8"; color: whiteText; font.pixelSize: 12; font.family: "Consolas" }
                                        Text { text: "停止位"; color: appTheme.muted; font.pixelSize: 11 }
                                        Text { text: "1"; color: whiteText; font.pixelSize: 12; font.family: "Consolas" }
                                        Text { text: "校验位"; color: appTheme.muted; font.pixelSize: 11 }
                                        Text { text: "None"; color: whiteText; font.pixelSize: 12; font.family: "Consolas" }
                                        Text { text: "流控"; color: appTheme.muted; font.pixelSize: 11 }
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
                                        color: settingsStore.hasDecimalMode ? clHighlight : (isDark ? Qt.rgba(255,255,255,0.2) : Qt.rgba(0,0,0,0.15))
                                        Rectangle {
                                            width: 20; height: 20; radius: 10
                                            color: settingsStore.hasDecimalMode ? appTheme.primaryText : whiteText
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
                }

                // 整条模块间隙均可拖动，提示柄位于间隙中央。
                Item {
                    Layout.preferredWidth: sidePanel < 0 ? 0 : panelGap
                    Behavior on Layout.preferredWidth { enabled: !sidePanelDragActive; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Layout.fillHeight: true
                    visible: sidePanel >= 0 || width > 1

                    PanelDivider {
                        id: sidePanelResizeHandle
                        anchors.fill: parent
                        enabled: sidePanel >= 0
                        accentColor: clHighlight
                        property int startWidth: 0
                        property int savedWidth: 0
                        onResizeStarted: {
                            startWidth = sidePanelCard.width
                            savedWidth = sidePanelWidth
                            sidePanelDragActive = true
                        }
                        onResizeMoved: (delta) => {
                            var requestedWidth = startWidth + delta
                            if (requestedWidth <= collapsePanelWidth) {
                                sidePanel = -1
                                sidePanelWidth = savedWidth
                            } else {
                                sidePanelWidth = Math.round(Math.min(maxSidePanelWidth, requestedWidth))
                            }
                        }
                        onResizeFinished: {
                            sidePanelDragActive = false
                            if (sidePanel >= 0) settingsStore.sidePanelWidth = sidePanelWidth
                        }
                    }
                }

                ColumnLayout {
                    id: centerColumn
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    spacing: 0
                    clip: true
                    
                    Rectangle {
                        id: terminalCard
                         Layout.fillWidth: true
                         Layout.fillHeight: true
                         Layout.minimumHeight: minTerminalHeight
                         color: clCanvas
                         radius: moduleRadius
                         border.color: clSurfaceLine
                         clip: true
                        ColumnLayout {
                            anchors.fill: parent
                             anchors.margins: 16
                             spacing: 10
                            RowLayout {
                                Text { text: "数据终端"
                                 color: clText
                                 font.pixelSize: 11
                                 font.bold: true }
                                Item { Layout.fillWidth: true }
                                
                                // 自动滚动开关
                                UiButton {
                                    visible: terminalCard.width >= 450
                                    text: "时间戳"
                                    selected: globalTimestamp
                                    hint: "显示消息时间戳"
                                    onClicked: globalTimestamp = !globalTimestamp
                                }
                                UiButton {
                                    id: scrollToggle
                                    text: terminalCard.width >= 350 ? (autoScroll ? "跟随" : "已锁定") : ""
                                    glyph: autoScroll ? "\uE74B" : "\uE72E"
                                    selected: !autoScroll
                                    hint: autoScroll ? "自动跟随新数据，点击锁定位置" : "滚动已锁定，点击恢复跟随"
                                    onClicked: autoScroll = !autoScroll
                                }

                                UiButton { text: terminalCard.width >= 350 ? "清除" : ""
                                 glyph: "\uE74D"
                                 hint: "清空终端显示"
                                 onClicked: { terminalModel.clear() } }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: clSurfaceLine
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                 Layout.fillHeight: true
                                 color: "transparent"
                                ListView {
                                    id: terminalView
                                     anchors.fill: parent
                                     anchors.topMargin: 4
                                     model: ListModel { id: terminalModel }
                                     spacing: 10
                                     clip: true
                                     boundsBehavior: Flickable.StopAtBounds
                                    delegate: Column {
                                        width: terminalView.width
                                         spacing: 3
                                         property bool delegateHover: false
                                         property bool expanded: false
                                         property bool wasTruncated: false
                                        RowLayout {
                                            width: parent.width
                                             layoutDirection: model.isSent ? Qt.RightToLeft : Qt.LeftToRight
                                             spacing: 6
                                            Text { text: model.timestamp
                                             font.pixelSize: 9
                                             color: appTheme.muted
                                             visible: globalTimestamp
                                             MouseArea {
                                                 anchors.fill: parent
                                                 onDoubleClicked: {
                                                     var txt = model.isHexMode ? model.contentHex : model.contentAscii
                                                     serialManager.copyToClipboard(txt)
                                                 }
                                             } }
                                            Rectangle {
                                                width: 38
                                                 height: 16
                                                 radius: 4
                                                 border.width: 0
                                                 color: appTheme.block
                                                Text { text: model.isHexMode ? "HEX" : "TXT"
                                                 anchors.centerIn: parent
                                                 font.pixelSize: 8
                                                 font.bold: true
                                                 color: clText }
                                                MouseArea { anchors.fill: parent
                                                 onClicked: { model.isHexMode = !model.isHexMode } }
                                            }
                                            Item { Layout.fillWidth: true }
                                        }
                                        Row {
                                            id: msgRow
                                            width: parent.width
                                             layoutDirection: model.isSent ? Qt.RightToLeft : Qt.LeftToRight
                                            Rectangle {
                                                width: msgText.width + 30
                                                 height: Math.max(msgCol.height + 12, 24)
                                                 radius: 16
                                                 color: model.isSent ? appTheme.selection : appTheme.block
                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.IBeamCursor
                                                    onDoubleClicked: {
                                                        var raw = model.isHexMode ? model.contentHex : model.contentAscii
                                                        serialManager.copyToClipboard(raw)
                                                    }
                                                    onContainsMouseChanged: delegateHover = containsMouse
                                                }
                                                Column {
                                                    id: msgCol
                                                    anchors.centerIn: parent
                                                    spacing: 3
                                                    Text { id: msgText
                                                     text: {
                                                         var raw = model.isHexMode ? model.contentHex : model.contentAscii
                                                         while (raw.length > 0 && (raw.charAt(raw.length-1) === '\r' || raw.charAt(raw.length-1) === '\n' || raw.charAt(raw.length-1) === ' '))
                                                             raw = raw.slice(0, -1)
                                                         return raw
                                                     }
                                                     width: Math.min(implicitWidth, terminalView.width * 0.75)
                                                     topPadding: 2; bottomPadding: 2
                                                     color: whiteText
                                                     font.family: "Consolas"
                                                     font.pixelSize: 13
                                                     wrapMode: Text.Wrap
                                                     maximumLineCount: expanded ? 2147483647 : 3
                                                     elide: Text.ElideRight
                                                     onTruncatedChanged: if (!expanded) wasTruncated = truncated
                                                     Component.onCompleted: if (!expanded) wasTruncated = truncated
                                                    }
                                                    Text { id: msgToggle
                                                     visible: expanded ? wasTruncated : msgText.truncated
                                                     text: expanded ? "收起 ▴" : "展开全文 ▾"
                                                     color: clText
                                                     font.pixelSize: 9
                                                     MouseArea {
                                                         anchors.fill: parent
                                                         cursorShape: Qt.PointingHandCursor
                                                         onClicked: expanded = !expanded
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

                    Item {
                        id: terminalSendResizeHandle
                        Layout.fillWidth: true
                        Layout.preferredHeight: terminalSendGap

                        PanelDivider {
                            id: terminalSendResizeMouse
                            anchors.fill: parent
                            vertical: false
                            accentColor: clHighlight
                            property int startHeight: 0
                            onResizeStarted: startHeight = sendCard.height
                            onResizeMoved: (delta) => {
                                sendPanelHeight = Math.max(minSendPanelHeight, Math.min(maxSendPanelHeight, startHeight - delta))
                            }
                        }
                    }

                    Rectangle {
                        id: sendCard
                        clip: true
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.minimumHeight: minSendPanelHeight
                        Layout.maximumHeight: maxSendPanelHeight
                        Layout.preferredHeight: sendPanelHeight
                        color: clToolSurface
                        radius: moduleRadius
                        border.color: sendInput.activeFocus ? Qt.rgba(clHighlight.r, clHighlight.g, clHighlight.b, 0.38) : clSurfaceLine
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 8
                                clip: true

                                Item {
                                    id: rxModeControl
                                    Layout.preferredWidth: showRxModeControl ? 112 : 0
                                    Layout.minimumWidth: 0
                                    Layout.preferredHeight: 30
                                    opacity: showRxModeControl ? 1 : 0
                                    enabled: showRxModeControl
                                    clip: true
                                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 6
                                        Text { text: "接收"; color: appTheme.muted; font.pixelSize: 10 }
                                        ModeSwitch {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 28
                                            model: ["TXT", "HEX"]
                                            currentIndex: globalRxHex ? 1 : 0
                                            onActivated: (index) => globalRxHex = index === 1
                                        }
                                    }
                                }

                                Item {
                                    id: txModeControl
                                    Layout.preferredWidth: showTxModeControl ? 112 : 0
                                    Layout.minimumWidth: 0
                                    Layout.preferredHeight: 30
                                    opacity: showTxModeControl ? 1 : 0
                                    enabled: showTxModeControl
                                    clip: true
                                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 6
                                        Text { text: "发送"; color: appTheme.muted; font.pixelSize: 10 }
                                        ModeSwitch {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 28
                                            model: ["TXT", "HEX"]
                                            currentIndex: globalTxHex ? 1 : 0
                                            onActivated: (index) => globalTxHex = index === 1
                                        }
                                    }
                                }

                                Item {
                                    id: timeControl
                                    Layout.preferredWidth: showTimeControl ? 88 : 0
                                    Layout.minimumWidth: 0
                                    Layout.preferredHeight: 30
                                    opacity: showTimeControl ? 1 : 0
                                    enabled: showTimeControl
                                    clip: true
                                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    IntervalControl {
                                        anchors.fill: parent
                                        interval: sendInterval
                                        onIntervalEdited: (milliseconds) => sendInterval = milliseconds
                                    }
                                }

                                Item {
                                    id: autoControl
                                    Layout.preferredWidth: showAutoControl ? 64 : 0
                                    Layout.minimumWidth: 0
                                    Layout.preferredHeight: 30
                                    opacity: showAutoControl ? 1 : 0
                                    enabled: showAutoControl
                                    clip: true
                                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    UiButton {
                                        anchors.fill: parent
                                        text: autoSending ? "停止" : "循环"
                                        kind: autoSending ? "danger" : "tonal"
                                        selected: autoSending
                                        hint: autoSending ? "停止定时发送" : "按设定间隔重复发送"
                                        onClicked: {
                                            inputSender.toggleRepeat()
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Item {
                                    id: checksumControl
                                    Layout.preferredWidth: showChecksumControl ? 90 : 0
                                    Layout.minimumWidth: 0
                                    Layout.preferredHeight: 30
                                    opacity: showChecksumControl ? 1 : 0
                                    enabled: showChecksumControl
                                    clip: true
                                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    ConfigComboBox {
                                        id: checksumCombo
                                        backdropItem: sendCard
                                        anchors.fill: parent
                                        model: ["无校验", "BCC", "Sum8", "CRC16"]
                                        font.pixelSize: 11
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: inputSender.notice || (inputSender.needsConversion
                                      ? "检测到文本，发送时会转为 HEX（UTF-8），不会切换发送模式。"
                                      : (!globalTxHex && settingsStore.lineEndingMode > 0
                                         ? "TXT 行尾：" + ["无", "LF (0A)", "CR (0D)", "CRLF (0D 0A)"][settingsStore.lineEndingMode] + "，可在设置中改为“无”。" : ""))
                                color: inputSender.needsConversion ? appTheme.warning : clText
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                 Layout.fillHeight: true
                                 color: "transparent"
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 8
                                    clip: true
                                    TextArea { id: sendInput
                                     Layout.fillWidth: true
                                     Layout.minimumWidth: 0
                                     Layout.fillHeight: true
                                     color: whiteText
                                     font.family: "Consolas"
                                     font.pixelSize: 14
                                     padding: 0
                                     topPadding: 4
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
                                    Rectangle { Layout.preferredWidth: (checksumCombo.currentIndex > 0 && sendCard.width >= 165) ? 50 : 0
                                     Layout.minimumWidth: 0
                                     Layout.fillHeight: true
                                     color: clInput
                                     radius: 8
                                     opacity: (checksumCombo.currentIndex > 0 && sendCard.width >= 165) ? 1 : 0
                                     visible: opacity > 0
                                     Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                     Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                     Column { anchors.centerIn: parent
                                     spacing: 2
                                     Text { text: "校验"
                                     color: appTheme.muted
                                     font.pixelSize: 9
                                     visible: window.width > 750 }
                                     Text { text: checksumValue
                                     color: whiteText
                                     font.bold: true
                                     font.pixelSize: 13 } } }
                                    UiButton { id: sendBtn
                                     Layout.preferredWidth: 60
                                     Layout.minimumWidth: 60
                                     Layout.preferredHeight: 40
                                     Layout.alignment: Qt.AlignBottom
                                     text: "发送"
                                     font.pixelSize: 12
                                     font.weight: Font.DemiBold
                                     kind: "primary"
                                     onClicked: doSend()
                                     }
                                }
                            }
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
                            radius: 12
                            border.color: clBorder
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 25
                                spacing: 15
                                RowLayout {
                                    spacing: 20
                                    Rectangle {
                                        width: 60; height: 60; radius: 12
                                        color: appTheme.block
                                        Text { text: "G"; color: whiteText; font.bold: true; font.pixelSize: 32; anchors.centerIn: parent }
                                    }
                                    ColumnLayout {
                                        Text { text: "MySerial Gemini"; color: whiteText; font.bold: true; font.pixelSize: 22 }
                                        Text { text: "v0.1.2 Alpha Build"; color: clText; font.pixelSize: 13 }
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
                                radius: 12
                                border.color: clBorder
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 20; spacing: 12
                                    Text { text: "运行环境"; color: whiteText; font.bold: true; font.pixelSize: 14 }
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
                                            Text { text: model.k; color: appTheme.muted; font.pixelSize: 12; Layout.preferredWidth: 100 }
                                            Text { text: model.v; color: whiteText; font.pixelSize: 12; font.family: "Consolas" }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 220
                                color: clCard
                                radius: 12
                                border.color: clBorder
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 20; spacing: 12
                                    Text { text: "技术支持"; color: whiteText; font.bold: true; font.pixelSize: 14 }
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
                                            Rectangle {
                                                Layout.preferredWidth: 44
                                                Layout.preferredHeight: 24
                                                radius: 6
                                                color: emailCopyMouse.containsMouse ? appTheme.hover : "transparent"
                                                border.color: emailCopyMouse.containsMouse ? clHighlight : "transparent"
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "复制"
                                                    color: clHighlight
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }
                                                MouseArea {
                                                    id: emailCopyMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: serialManager.copyToClipboard("mmooka001@gmail.com")
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
                 radius: 12
                 anchors.centerIn: parent
                 color: clCard
                 border.color: clSurfaceLine
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
                     color: appTheme.muted
                     font.pixelSize: 12
                     Layout.alignment: Qt.AlignHCenter }
                    RowLayout {
                        spacing: 15
                        Layout.fillWidth: true
                        UiButton {
                            text: "取消"
                            kind: "tonal"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            onClicked: { deleteConfirmOverlay.visible = false } 
                        }
                        UiButton {
                            text: "确定删除"
                            kind: "danger"
                            selected: true
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            onClicked: { 
                                if (deleteType === "group") { commandStore.deleteGroup(targetGroupIdx) } 
                                else if (deleteType === "command") { commandStore.deleteCommand(targetGroupIdx, targetCmdIdx) } 
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
            onAccepted: commandStore.importFromFile(selectedFile.toString())
        }
        FileDialog {
            id: exportFileDialog
            title: "导出指令预设"
            nameFilters: ["JSON files (*.json)", "All files (*)"]
            fileMode: FileDialog.SaveFile
            onAccepted: commandStore.exportToFile(selectedFile.toString())
        }

        Rectangle {
            id: statusBar
            width: parent.width
            height: 28
            color: "transparent"
            anchors.bottom: parent.bottom
            z: 100

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15 + leftRailWidth
                anchors.rightMargin: 15
                spacing: 15

                RowLayout {
                    spacing: 8
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: serialManager.isOpen ? appTheme.success : appTheme.muted
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
                        color: clText
                        font.pixelSize: 10
                        font.family: "Consolas"
                    }
                    Text {
                        text: "▲ TX: " + recordStore.txCount + " B"
                        color: clText
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
                        color: exportMouse.containsMouse ? clInput : "transparent"
                        Text {
                            text: "导出"
                            anchors.centerIn: parent
                            color: clText
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: exportMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                exportRecordDialog.currentFile = defaultExportFileUrl(recordExportFileName())
                                exportRecordDialog.open()
                            }
                        }
                    }
                    Rectangle {
                        width: 42; height: 20; radius: 4
                        color: clearRecMouse.containsMouse ? clInput : "transparent"
                        Text {
                            text: "清空"
                            anchors.centerIn: parent
                            color: appTheme.muted
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
            nameFilters: ["CSV files (*.csv)", "All files (*)"]
            fileMode: FileDialog.SaveFile
            onAccepted: recordStore.exportRecords(selectedFile.toString())
        }

    }

    // Resize handles (outside rootRect so clip doesn't cut them)
    MouseArea { enabled: !window.edgeToEdge; z: 1000; width: 8
     anchors.left: parent.left
     anchors.top: parent.top
     anchors.bottom: parent.bottom
     cursorShape: Qt.SizeHorCursor
     onPressed: { window.startSystemResize(Qt.LeftEdge) } }
    MouseArea { enabled: !window.edgeToEdge; z: 1000; width: 8
     anchors.right: parent.right
     anchors.top: parent.top
     anchors.bottom: parent.bottom
     cursorShape: Qt.SizeHorCursor
     onPressed: { window.startSystemResize(Qt.RightEdge) } }
    MouseArea { enabled: !window.edgeToEdge; z: 1000; height: 8
     anchors.top: parent.top
     anchors.left: parent.left
     anchors.right: parent.right
     cursorShape: Qt.SizeVerCursor
     onPressed: { window.startSystemResize(Qt.TopEdge) } }
    MouseArea { enabled: !window.edgeToEdge; z: 1000; height: 8
     anchors.bottom: parent.bottom
     anchors.left: parent.left
     anchors.right: parent.right
     cursorShape: Qt.SizeVerCursor
     onPressed: { window.startSystemResize(Qt.BottomEdge) } }
    MouseArea { enabled: !window.edgeToEdge; z: 1000; width: 16
     height: 16
     anchors.left: parent.left
     anchors.top: parent.top
     cursorShape: Qt.SizeFDiagCursor
     onPressed: { window.startSystemResize(Qt.TopEdge | Qt.LeftEdge) } }
    MouseArea { enabled: !window.edgeToEdge; z: 1000; width: 16
     height: 16
     anchors.right: parent.right
     anchors.top: parent.top
     cursorShape: Qt.SizeBDiagCursor
     onPressed: { window.startSystemResize(Qt.TopEdge | Qt.RightEdge) } }
    MouseArea { enabled: !window.edgeToEdge; z: 1000; width: 16
     height: 16
     anchors.left: parent.left
     anchors.bottom: parent.bottom
     cursorShape: Qt.SizeBDiagCursor
     onPressed: { window.startSystemResize(Qt.BottomEdge | Qt.LeftEdge) } }
    MouseArea { enabled: !window.edgeToEdge; z: 1000; width: 16
     height: 16
     anchors.right: parent.right
     anchors.bottom: parent.bottom
     cursorShape: Qt.SizeFDiagCursor
     onPressed: { window.startSystemResize(Qt.BottomEdge | Qt.RightEdge) } }

    Connections {
        target: serialManager
        function onIsOpenChanged() {
            if (!serialManager.isOpen) {
                loopSending = false
                loopIndex = -1
                loopTimer.stop()
            }
        }
        function onDataReceived(ascii, hex, isSent, isHex) {
            terminalModel.append({ "contentAscii": ascii, "contentHex": hex, "isHexMode": isSent ? isHex : globalRxHex, "isSent": isSent, "timestamp": Qt.formatDateTime(new Date(), "hh:mm:ss.zzz") })
            if (autoScroll) {
                terminalView.positionViewAtEnd()
            }
        }
        function onErrorOccurred(error) {
            terminalModel.append({ "contentAscii": "错误: " + error, "contentHex": "", "isHexMode": false, "isSent": false, "timestamp": Qt.formatDateTime(new Date(), "hh:mm:ss.zzz") })
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
        layoutReady = true
        acrylic.enable(window)
        updateAcrylicTint()
        serialManager.lineEndingMode = settingsStore.lineEndingMode
        startupPortRefreshTimer.start()
    }

    Popup {
        id: themePopup
        x: Math.max(8, window.width - width - 145)
        y: rootRect.y + titleBar.height + 2
        width: 312
        implicitHeight: Math.min(themeColumn.implicitHeight + 24, window.height - y - 12)
        padding: 12
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: appTheme.raised
            radius: 14
            border.color: appTheme.line
        }
        contentItem: Flickable {
            contentHeight: themeColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator { }
            ColumnLayout {
                id: themeColumn
                width: parent.width
                spacing: 10
                Text { text: "外观"; color: whiteText; font.pixelSize: 14; font.weight: Font.DemiBold }
                ModeSwitch {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    model: ["深色", "浅色", "系统"]
                    currentIndex: settingsStore.appearanceMode
                    onActivated: (index) => settingsStore.appearanceMode = index
                }
                Text { text: "配色风格"; color: appTheme.secondary; font.pixelSize: 11 }
                ModeSwitch {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    model: appTheme.styleNames
                    currentIndex: settingsStore.colorStyle
                    onActivated: (index) => settingsStore.colorStyle = index
                }
                Text { text: "预设强调色"; color: appTheme.secondary; font.pixelSize: 11 }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: themeNames
                        delegate: Button {
                            id: preset
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            padding: 0
                            hoverEnabled: true
                            Accessible.name: String(modelData)
                            ToolTip.visible: hovered
                            ToolTip.text: String(modelData)
                            ToolTip.delay: 500
                            background: Rectangle { radius: 9; color: preset.hovered ? appTheme.hover : "transparent" }
                            contentItem: Item {
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 24; height: 24; radius: 8
                                    color: appTheme.seeds[preset.index]
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uE73E"
                                        font.family: "Segoe Fluent Icons"
                                        font.pixelSize: 11
                                        color: "#151920"
                                        visible: !settingsStore.useCustomAccent && window.themeMode === preset.index
                                    }
                                }
                            }
                            onClicked: {
                                settingsStore.themeMode = index
                                settingsStore.useCustomAccent = false
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "自定义强调色"; color: appTheme.secondary; font.pixelSize: 11; Layout.fillWidth: true }
                    UiButton {
                        text: settingsStore.useCustomAccent ? "恢复预设" : "使用自定义"
                        Layout.preferredHeight: 24
                        onClicked: settingsStore.useCustomAccent = !settingsStore.useCustomAccent
                    }
                }
                AccentColorPicker {
                    id: accentPicker
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    theme: appTheme
                    selectedColor: appTheme.seed
                    onColorEdited: (color) => {
                        settingsStore.customAccent = color.toString()
                        settingsStore.useCustomAccent = true
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: settingsStore.colorStyle === 3 ? "单色风格保留灰阶，其他风格会显示强调色。" : "拖动色谱，或输入 HEX 后回车。"
                    color: appTheme.muted
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
