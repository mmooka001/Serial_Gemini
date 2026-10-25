import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: picker
    required property AppTheme theme
    property color selectedColor: "#82aaff"
    property real hue: 0
    property real saturation: 0
    property real value: 1
    property bool ready: false
    signal colorEdited(color color)
    implicitHeight: 210
    implicitWidth: 264

    function normalizeHex(input: string): string {
        var text = input.trim().replace(/^#/, "").toUpperCase()
        if (!/^([0-9A-F]{3}|[0-9A-F]{6})$/.test(text)) return ""
        if (text.length === 3) text = text[0] + text[0] + text[1] + text[1] + text[2] + text[2]
        return "#" + text
    }
    function syncColor() {
        if (svMouse.pressed || hueSlider.pressed) return
        if (selectedColor.hsvHue >= 0) hue = selectedColor.hsvHue
        saturation = selectedColor.hsvSaturation
        value = selectedColor.hsvValue
        if (!hexField.activeFocus) hexField.text = selectedColor.toString().toUpperCase()
    }
    function editColor() {
        var color = Qt.hsva(hue, saturation, value, 1)
        colorEdited(color)
        hexField.text = color.toString().toUpperCase()
    }
    function pickAt(x: real, y: real) {
        saturation = Math.max(0, Math.min(1, x / svField.width))
        value = 1 - Math.max(0, Math.min(1, y / svField.height))
        editColor()
    }
    onSelectedColorChanged: if (ready) syncColor()
    Component.onCompleted: { ready = true; syncColor() }

    Rectangle {
        id: svField
        anchors.left: parent.left
        anchors.right: parent.right
        height: 132
        radius: 9
        color: Qt.hsva(picker.hue, 1, 1, 1)
        Rectangle {
            anchors.fill: parent
            radius: 9
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: 9
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: "black" }
            }
        }
        Rectangle {
            x: Math.max(0, Math.min(parent.width - width, picker.saturation * parent.width - width / 2))
            y: Math.max(0, Math.min(parent.height - height, (1 - picker.value) * parent.height - height / 2))
            width: 14; height: 14; radius: 7
            color: Qt.hsva(picker.hue, picker.saturation, picker.value, 1)
            border.color: "white"
            border.width: 2
            Rectangle { anchors.fill: parent; anchors.margins: -1; radius: 8; color: "transparent"; border.color: "#80000000" }
        }
        MouseArea {
            id: svMouse
            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.CrossCursor
            focus: false
            onPressed: (mouse) => { forceActiveFocus(); picker.pickAt(mouse.x, mouse.y) }
            onPositionChanged: (mouse) => { if (pressed) picker.pickAt(mouse.x, mouse.y) }
            Keys.onLeftPressed: { picker.saturation = Math.max(0, picker.saturation - 0.01); picker.editColor() }
            Keys.onRightPressed: { picker.saturation = Math.min(1, picker.saturation + 0.01); picker.editColor() }
            Keys.onUpPressed: { picker.value = Math.min(1, picker.value + 0.01); picker.editColor() }
            Keys.onDownPressed: { picker.value = Math.max(0, picker.value - 0.01); picker.editColor() }
            Accessible.name: "饱和度与亮度色谱"
        }
    }
    Slider {
        id: hueSlider
        anchors.top: svField.bottom
        anchors.topMargin: 7
        width: parent.width
        height: 24
        padding: 0
        from: 0; to: 1
        stepSize: 1 / 360
        value: picker.hue
        Accessible.name: "色相"
        onMoved: { picker.hue = value; picker.editColor() }
        background: Rectangle {
            y: (parent.height - height) / 2
            width: parent.width
            height: 10
            radius: 5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#ff0000" }
                GradientStop { position: 1/6; color: "#ffff00" }
                GradientStop { position: 2/6; color: "#00ff00" }
                GradientStop { position: 3/6; color: "#00ffff" }
                GradientStop { position: 4/6; color: "#0000ff" }
                GradientStop { position: 5/6; color: "#ff00ff" }
                GradientStop { position: 1; color: "#ff0000" }
            }
        }
        handle: Rectangle {
            x: hueSlider.visualPosition * (hueSlider.width - width)
            y: (hueSlider.height - height) / 2
            width: 16; height: 16; radius: 8
            color: Qt.hsva(picker.hue, 1, 1, 1)
            border.color: "white"; border.width: 2
        }
    }
    RowLayout {
        anchors.top: hueSlider.bottom
        anchors.topMargin: 7
        width: parent.width
        height: 34
        spacing: 8
        Rectangle { Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 8; color: picker.selectedColor; border.color: picker.theme.line }
        Text { text: "HEX"; color: picker.theme.secondary; font.pixelSize: 10 }
        TextField {
            id: hexField
            objectName: "hexField"
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            selectByMouse: true
            font.family: "Consolas"
            font.pixelSize: 12
            color: picker.theme.text
            placeholderText: "#RRGGBB"
            placeholderTextColor: picker.theme.muted
            maximumLength: 7
            validator: RegularExpressionValidator { regularExpression: /#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})/ }
            background: Rectangle {
                radius: 8
                color: picker.theme.block
                border.color: hexField.activeFocus ? picker.theme.primary : "transparent"
            }
            onActiveFocusChanged: {
                if (!activeFocus && !acceptableInput)
                    text = picker.selectedColor.toString().toUpperCase()
            }
            onEditingFinished: {
                var hex = picker.normalizeHex(text)
                if (hex.length) { picker.colorEdited(hex); text = hex }
                else text = picker.selectedColor.toString().toUpperCase()
            }
        }
    }
}
