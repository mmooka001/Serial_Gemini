import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ActionButton {
    id: control
    property int interval: 500
    signal intervalEdited(int milliseconds)
    text: interval + " ms"
    kind: "tonal"
    hint: "设置循环发送间隔"
    onClicked: editor.opened ? editor.close() : editor.open()
    Popup {
        id: editor
        objectName: "intervalPopup"
        y: -height - 6
        width: 240
        implicitHeight: form.implicitHeight + 24
        padding: 12
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: {
            milliseconds.text = String(control.interval)
            milliseconds.forceActiveFocus()
            milliseconds.selectAll()
        }
        function apply() {
            if (!milliseconds.acceptableInput) return
            control.intervalEdited(parseInt(milliseconds.text, 10))
            close()
        }
        background: Rectangle { color: control.theme.raised; radius: 12; border.color: control.theme.line }
        contentItem: ColumnLayout {
            id: form
            spacing: 10
            Text { text: "循环间隔"; color: control.theme.text; font.pixelSize: 12; font.weight: Font.DemiBold }
            RowLayout {
                spacing: 8
                TextField {
                    id: milliseconds
                    objectName: "millisecondsInput"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    selectByMouse: true
                    font.family: "Consolas"
                    font.pixelSize: 14
                    color: control.theme.text
                    validator: IntValidator { bottom: 50; top: 3600000 }
                    background: Rectangle { color: control.theme.block; radius: 8; border.color: milliseconds.activeFocus ? control.theme.primary : "transparent" }
                    Keys.onReturnPressed: editor.apply()
                    Keys.onEnterPressed: editor.apply()
                }
                Text { text: "ms"; color: control.theme.secondary; font.pixelSize: 11 }
            }
            RowLayout {
                Repeater {
                    model: [100, 500, 1000]
                    delegate: ActionButton {
                        required property var modelData
                        theme: control.theme
                        text: String(modelData)
                        Layout.fillWidth: true
                        kind: "tonal"
                        onClicked: { milliseconds.text = String(modelData); editor.apply() }
                    }
                }
            }
            RowLayout {
                Text { text: "50 ms ～ 1 小时"; color: control.theme.muted; font.pixelSize: 10; Layout.fillWidth: true }
                ActionButton { theme: control.theme; text: "确定"; enabled: milliseconds.acceptableInput; onClicked: editor.apply() }
            }
        }
    }
}
