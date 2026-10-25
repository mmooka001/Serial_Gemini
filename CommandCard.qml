import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Templates as T

Rectangle {
    id: card
    required property AppTheme theme
    property string commandName: ""
    property string payload: ""
    property bool hexMode: false
    property bool loopSelected: false
    property bool reorderHeld: false
    property point pressScenePosition
    property point latestScenePosition
    readonly property bool editing: nameEditor.activeFocus || payloadEditor.activeFocus
    readonly property string draftName: nameEditor.text
    readonly property string draftPayload: payloadEditor.text
    property bool commitPending: false
    signal edited(string name, string payload)
    signal sendRequested(string payload, bool hex)
    signal formatToggled(string name, string payload)
    signal loopToggled()
    signal deleteRequested()
    signal reorderStarted(point scenePosition)
    signal reorderMoved(point scenePosition)
    signal reorderFinished(point scenePosition, string name, string payload)
    signal reorderCanceled()
    implicitHeight: content.implicitHeight + 16
    radius: 10
    color: editing ? theme.block : hover.hovered ? theme.alpha(theme.block, 0.7) : theme.alpha(theme.block, 0.35)
    border.color: payloadEditor.activeFocus || reorderHeld ? theme.primary : loopSelected ? theme.alpha(theme.primary, 0.4) : "transparent"
    opacity: reorderHeld ? 0.4 : 1
    HoverHandler { id: hover }
    Item {
        anchors.fill: parent
        z: 10
        PointHandler {
            id: pointer
            target: null
            acceptedButtons: Qt.LeftButton
            cursorShape: card.reorderHeld ? Qt.ClosedHandCursor : undefined
            onActiveChanged: {
                if (active) {
                    card.pressScenePosition = point.scenePosition
                    card.latestScenePosition = point.scenePosition
                    if (card.canStartReorder(point.position)) holdTimer.start()
                } else {
                    holdTimer.stop()
                    if (card.reorderHeld) {
                        card.reorderHeld = false
                        card.reorderFinished(card.latestScenePosition, nameEditor.text, payloadEditor.text)
                        return
                    }
                    Qt.callLater(card.flushCommit)
                }
            }
            onPointChanged: {
                if (!active) return
                card.latestScenePosition = point.scenePosition
                if (card.reorderHeld) card.reorderMoved(point.scenePosition)
                else if (Math.abs(point.scenePosition.x - card.pressScenePosition.x)
                         + Math.abs(point.scenePosition.y - card.pressScenePosition.y) > Qt.styleHints.startDragDistance)
                    holdTimer.stop()
            }
        }
        Timer {
            id: holdTimer
            interval: 450
            onTriggered: {
                if (!pointer.active) return
                card.reorderHeld = true
                nameEditor.deselect()
                payloadEditor.deselect()
                card.forceActiveFocus()
                card.reorderStarted(card.latestScenePosition)
            }
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.WithinBounds
            onTapped: (eventPoint) => card.openActions(eventPoint.position)
        }
    }
    Connections {
        target: card.Window.window
        function onActiveChanged() {
            if (target && !target.active) {
                holdTimer.stop()
                if (card.reorderHeld) {
                    card.reorderHeld = false
                    card.reorderCanceled()
                }
            }
        }
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape && reorderHeld) {
            reorderHeld = false
            reorderCanceled()
            event.accepted = true
        } else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier)) {
            openActions(Qt.point(width - 160, 30))
            event.accepted = true
        }
    }

    function canStartReorder(position: point): bool {
        for (var button of [loopButton, formatButton, moreButton, sendButton]) {
            var local = button.mapFromItem(card, position.x, position.y)
            if (button.contains(local)) return false
        }
        return true
    }
    function openActions(position: point) {
        if (reorderHeld) return
        actionsPopup.x = Math.max(0, Math.min(width - actionsPopup.width, position.x))
        actionsPopup.y = position.y
        actionsPopup.open()
    }

    function requestCommit() {
        // 点击结束后再刷新列表，避免正在操作的按钮被提前销毁。
        commitPending = true
        Qt.callLater(flushCommit)
    }
    function flushCommit() {
        if (!commitPending || pointer.active || reorderHeld || actionsPopup.visible) return
        commitPending = false
        commit()
    }

    function commit() {
        if (nameEditor.text !== commandName || payloadEditor.text !== payload)
            edited(nameEditor.text, payloadEditor.text)
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            spacing: 2
            Button {
                id: loopButton
                objectName: "loopSelection"
                Layout.preferredWidth: 22
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                padding: 0
                checkable: false
                hoverEnabled: true
                Accessible.role: Accessible.CheckBox
                Accessible.name: "加入循环发送"
                Accessible.checked: card.loopSelected
                ToolTip.visible: hovered
                ToolTip.text: "加入循环发送"
                ToolTip.delay: 650
                background: Item {
                    Rectangle {
                        anchors.centerIn: parent
                        width: 14; height: 14; radius: 4
                        color: card.loopSelected ? card.theme.primary : "transparent"
                        border.color: card.loopSelected ? card.theme.primary : card.theme.alpha(card.theme.secondary, loopButton.hovered ? 0.8 : 0.35)
                        Text {
                            anchors.centerIn: parent
                            visible: card.loopSelected
                            text: "\uE73E"
                            font.family: "Segoe Fluent Icons"
                            font.pixelSize: 10
                            color: card.theme.primaryText
                        }
                    }
                }
                contentItem: Item {}
                onClicked: card.loopToggled()
            }
            TextField {
                id: nameEditor
                objectName: "commandNameEditor"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                text: card.commandName
                placeholderText: "指令名称"
                placeholderTextColor: card.theme.muted
                font.pixelSize: 11
                color: activeFocus ? card.theme.text : card.theme.secondary
                hoverEnabled: true
                ToolTip.visible: hovered && !activeFocus && contentWidth > width
                ToolTip.text: card.commandName
                ToolTip.delay: 650
                padding: 0
                leftPadding: 6; rightPadding: 6; topPadding: 0; bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                background: Rectangle {
                    radius: 8
                    color: nameEditor.activeFocus ? card.theme.raised : "transparent"
                    border.color: nameEditor.activeFocus ? card.theme.alpha(card.theme.primary, 0.65) : "transparent"
                }
                selectByMouse: !card.reorderHeld
                readOnly: card.reorderHeld
                selectionColor: card.theme.primary
                selectedTextColor: card.theme.primaryText
                Accessible.name: "指令名称"
                ContextMenu.menu: null
                ContextMenu.onRequested: (position) => card.openActions(nameEditor.mapToItem(card, position.x, position.y))
                onEditingFinished: card.requestCommit()
            }
            ActionButton {
                id: formatButton
                objectName: "commandFormatToggle"
                theme: card.theme
                text: card.hexMode ? "HEX" : "TXT"
                hint: "切换 TXT / HEX"
                kind: "tonal"
                selected: card.hexMode
                Layout.preferredWidth: 34
                Layout.preferredHeight: 24
                leftPadding: 3; rightPadding: 3
                font.pixelSize: 9
                onClicked: card.formatToggled(nameEditor.text, payloadEditor.text)
            }
            ActionButton {
                id: moreButton
                objectName: "commandMore"
                theme: card.theme
                glyph: "\uE712"
                hint: "指令操作"
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                leftPadding: 0; rightPadding: 0
                onClicked: card.openActions(Qt.point(card.width - 164, 34))
            }
            ActionButton {
                id: sendButton
                objectName: "commandSend"
                theme: card.theme
                glyph: "\uE724"
                hint: "发送指令"
                Layout.preferredWidth: 26
                Layout.preferredHeight: 24
                leftPadding: 0; rightPadding: 0
                onClicked: card.sendRequested(payloadEditor.text, card.hexMode)
            }
        }

        ScrollView {
            id: payloadView
            objectName: "commandPayloadView"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: Math.max(30, Math.min(90, payloadEditor.implicitHeight))
            padding: 0
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical: T.ScrollBar {
                id: payloadScrollBar
                width: 8
                padding: 1
                policy: ScrollBar.AsNeeded
                hoverEnabled: true
                minimumSize: Math.min(1, 18 / Math.max(1, height))
                opacity: size < 1 && (active || hovered || hover.hovered) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                background: Item {}
                contentItem: Item {
                    implicitWidth: 6
                    implicitHeight: 6
                    Rectangle {
                        anchors.centerIn: parent
                        width: payloadScrollBar.hovered || payloadScrollBar.pressed ? 4 : 3
                        height: parent.height
                        radius: width / 2
                        color: payloadScrollBar.pressed ? card.theme.primary : card.theme.secondary
                        opacity: payloadScrollBar.pressed ? 0.8 : 0.4
                        Behavior on width { NumberAnimation { duration: 100 } }
                    }
                }
            }
            TextArea {
                id: payloadEditor
                objectName: "commandPayloadEditor"
                width: payloadView.availableWidth
                text: card.payload
                textFormat: TextEdit.PlainText
                font.family: "Consolas"
                font.pixelSize: 13
                color: card.theme.text
                wrapMode: TextEdit.Wrap
                padding: 3
                leftPadding: 3; rightPadding: 8; topPadding: 3; bottomPadding: 3
                background: null
                placeholderText: "输入指令内容"
                placeholderTextColor: card.theme.muted
                selectByMouse: !card.reorderHeld
                readOnly: card.reorderHeld
                selectionColor: card.theme.primary
                selectedTextColor: card.theme.primaryText
                persistentSelection: false
                Accessible.name: "指令内容"
                ContextMenu.menu: null
                ContextMenu.onRequested: (position) => card.openActions(payloadEditor.mapToItem(card, position.x, position.y))
                onActiveFocusChanged: if (!activeFocus) card.requestCommit()
            }
        }
    }

    Popup {
        id: actionsPopup
        objectName: "commandActionsPopup"
        x: Math.max(0, card.width - width - 8)
        y: 34
        width: 156
        padding: 5
        implicitHeight: actions.implicitHeight + 10
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: Qt.callLater(card.flushCommit)
        background: Rectangle {
            radius: 10
            color: card.theme.raised
            border.color: card.theme.line
        }
        contentItem: Column {
            id: actions
            spacing: 2
            ActionButton {
                objectName: "commandMenuSend"
                theme: card.theme
                width: parent.width
                glyph: "\uE724"
                text: "发送指令"
                onClicked: { actionsPopup.close(); card.sendRequested(payloadEditor.text, card.hexMode) }
            }
            ActionButton {
                objectName: "commandFormat"
                theme: card.theme
                width: parent.width
                text: card.hexMode ? "切换为 TXT" : "切换为 HEX"
                onClicked: {
                    actionsPopup.close()
                    card.formatToggled(nameEditor.text, payloadEditor.text)
                }
            }
            ActionButton {
                objectName: "commandMenuSelect"
                theme: card.theme
                width: parent.width
                glyph: card.loopSelected ? "\uE73A" : "\uE739"
                text: card.loopSelected ? "取消勾选" : "勾选指令"
                onClicked: { actionsPopup.close(); card.loopToggled() }
            }
            ActionButton {
                objectName: "commandDelete"
                theme: card.theme
                width: parent.width
                glyph: "\uE74D"
                text: "删除指令"
                kind: "danger"
                onClicked: { actionsPopup.close(); card.deleteRequested() }
            }
        }
    }
}
