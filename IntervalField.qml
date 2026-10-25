import QtQuick
import QtQuick.Controls

Rectangle {
    id: control
    required property AppTheme theme
    property int interval: 500
    signal intervalEdited(int milliseconds)
    implicitWidth: 88
    implicitHeight: 28
    radius: 8
    color: milliseconds.activeFocus ? theme.block : "transparent"
    border.color: milliseconds.activeFocus ? theme.primary : "transparent"
    onIntervalChanged: if (!milliseconds.activeFocus) milliseconds.text = String(interval)

    function commit() {
        if (milliseconds.acceptableInput) {
            var value = parseInt(milliseconds.text, 10)
            if (value !== interval) intervalEdited(value)
        }
        milliseconds.text = String(interval)
    }

    Row {
        anchors.centerIn: parent
        spacing: 4
        TextField {
            id: milliseconds
            objectName: "millisecondsInput"
            width: Math.max(24, Math.min(control.width - 28, contentWidth + 6))
            height: control.height
            text: String(control.interval)
            padding: 0
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            selectByMouse: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: control.theme.text
            selectionColor: control.theme.selection
            selectedTextColor: control.theme.text
            font.family: "Consolas"
            font.pixelSize: 11
            validator: IntValidator { bottom: 50; top: 3600000 }
            background: null
            Accessible.name: "循环间隔，毫秒"
            onActiveFocusChanged: {
                if (activeFocus) Qt.callLater(selectAll)
                else if (!acceptableInput) text = String(control.interval)
            }
            onEditingFinished: control.commit()
            Keys.onReturnPressed: { control.commit(); control.forceActiveFocus() }
            Keys.onEnterPressed: { control.commit(); control.forceActiveFocus() }
            Keys.onEscapePressed: { text = String(control.interval); control.forceActiveFocus() }
        }
        Text {
            text: "ms"
            height: control.height
            verticalAlignment: Text.AlignVCenter
            color: control.theme.secondary
            font.pixelSize: 10
        }
    }
}
