import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: card
    required property AppTheme theme
    property string commandName: ""
    property string payload: ""
    property bool hexMode: false
    property bool loopSelected: false
    readonly property bool editing: nameEditor.activeFocus || payloadEditor.activeFocus
    property bool commitPending: false
    signal edited(string name, string payload)
    signal sendRequested(string payload, bool hex)
    signal formatToggled(string name, string payload)
    signal loopToggled()
    signal deleteRequested()
    implicitHeight: content.implicitHeight + 16
    radius: 10
    color: editing ? theme.block : hover.hovered ? theme.alpha(theme.block, 0.7) : theme.alpha(theme.block, 0.35)
    border.color: editing ? theme.primary : loopSelected ? theme.alpha(theme.primary, 0.4) : "transparent"
    HoverHandler { id: hover }
    PointHandler {
        id: pointer
        target: null
        onActiveChanged: if (!active) Qt.callLater(card.flushCommit)
    }

    function requestCommit() {
        // 点击结束后再刷新列表，避免正在操作的按钮被提前销毁。
        commitPending = true
        Qt.callLater(flushCommit)
    }
    function flushCommit() {
        if (!commitPending || pointer.active || actionsPopup.visible) return
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
            Layout.preferredHeight: 24
            spacing: 2
            Button {
                id: loopButton
                objectName: "loopSelection"
                Layout.preferredWidth: 22
                Layout.preferredHeight: 24
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
                Layout.preferredHeight: 24
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
                leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
                background: null
                selectByMouse: true
                selectionColor: card.theme.primary
                selectedTextColor: card.theme.primaryText
                Accessible.name: "指令名称"
                onEditingFinished: card.requestCommit()
            }
            Text {
                text: card.hexMode ? "HEX" : "TXT"
                color: card.theme.muted
                font.family: "Consolas"
                font.pixelSize: 9
                Layout.rightMargin: 3
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
                onClicked: actionsPopup.open()
            }
            ActionButton {
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
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
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
                selectByMouse: true
                selectionColor: card.theme.primary
                selectedTextColor: card.theme.primaryText
                persistentSelection: false
                Accessible.name: "指令内容"
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
