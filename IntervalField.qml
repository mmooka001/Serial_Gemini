import QtQuick
import QtQuick.Controls

Rectangle {
    id: control
    required property AppTheme theme
    property int interval: 500
    property int minimum: 1
    property int maximum: 3600000
    property string unit: "ms"
    property bool framed: false
    property string editorName: "millisecondsInput"
    property string hint: minimum.toLocaleString(Qt.locale(), "f", 0) + "–"
                          + maximum.toLocaleString(Qt.locale(), "f", 0) + " " + unit
    signal intervalEdited(int milliseconds)
    implicitWidth: 88
    implicitHeight: 28
    radius: 8
    color: milliseconds.activeFocus ? theme.block : "transparent"
    border.color: milliseconds.activeFocus ? theme.primary : "transparent"
    onIntervalChanged: if (!milliseconds.activeFocus || framed) milliseconds.text = String(interval)

    function commit() {
        if (milliseconds.acceptableInput) {
            var value = parseInt(milliseconds.text, 10)
            if (value !== interval) intervalEdited(value)
        }
        milliseconds.text = String(interval)
    }

    function step(delta: int) {
        const value = Math.max(minimum, Math.min(maximum, interval + delta))
        if (value !== interval) intervalEdited(value)
        milliseconds.text = String(interval)
    }

    component StepButton: Button {
        id: stepButton
        required property int delta
        objectName: control.editorName + (delta > 0 ? "Up" : "Down")
        enabled: delta > 0 ? control.interval < control.maximum : control.interval > control.minimum
        autoRepeat: true
        padding: 0
        focusPolicy: Qt.TabFocus
        Accessible.name: delta > 0 ? "增加字号" : "减小字号"
        contentItem: Text {
            text: stepButton.delta > 0 ? "▴" : "▾"
            font.pixelSize: control.theme.uiPixels(11)
            color: stepButton.enabled ? control.theme.text : control.theme.muted
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 4
            color: stepButton.down || stepButton.hovered ? control.theme.hover : "transparent"
        }
        onClicked: control.step(delta)
    }

    Row {
        anchors.centerIn: parent
        spacing: 4
        TextField {
            id: milliseconds
            objectName: control.editorName
            width: control.framed ? control.width - unitLabel.implicitWidth - arrows.width - 8
                                  : Math.max(24, Math.min(control.width - unitLabel.implicitWidth - 8, contentWidth + 6))
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
            font.pixelSize: control.theme.uiPixels(control.framed ? 12 : 11)
            validator: IntValidator { bottom: control.minimum; top: control.maximum }
            background: Rectangle {
                visible: control.framed
                radius: 7
                color: control.theme.block
                border.color: milliseconds.activeFocus ? control.theme.primary : control.theme.line
            }
            Accessible.name: control.hint
            onActiveFocusChanged: {
                if (activeFocus) Qt.callLater(selectAll)
                else if (!acceptableInput) text = String(control.interval)
            }
            onEditingFinished: control.commit()
            Keys.onReturnPressed: { control.commit(); control.forceActiveFocus() }
            Keys.onEnterPressed: { control.commit(); control.forceActiveFocus() }
            Keys.onEscapePressed: { text = String(control.interval); control.forceActiveFocus() }
            Keys.onUpPressed: (event) => { if (control.framed) control.step(1); else event.accepted = false }
            Keys.onDownPressed: (event) => { if (control.framed) control.step(-1); else event.accepted = false }
        }
        Column {
            id: arrows
            visible: control.framed
            width: Math.max(18, control.theme.uiPixels(18))
            StepButton { delta: 1; width: arrows.width; height: control.height / 2 }
            StepButton { delta: -1; width: arrows.width; height: control.height / 2 }
        }
        Text {
            id: unitLabel
            text: control.unit
            height: control.height
            verticalAlignment: Text.AlignVCenter
            color: control.theme.secondary
            font.pixelSize: control.theme.uiPixels(10)
        }
    }
    HoverHandler { id: hover }
    HintBubble {
        theme: control.theme
        text: control.hint
        delay: control.unit === "ms" ? 0 : 550
        timeout: control.unit === "ms" ? -1 : 5000
        visible: control.unit === "ms" ? milliseconds.activeFocus : hover.hovered
    }
}
