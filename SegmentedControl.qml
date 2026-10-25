pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Rectangle {
    id: control
    required property AppTheme theme
    property var model: []
    property int currentIndex: 0
    property int textSize: 10
    signal activated(int index)
    implicitWidth: model.length * 38 + 4
    implicitHeight: 28
    radius: 10
    color: theme.block
    clip: true

    Rectangle {
        x: 2 + control.currentIndex * (control.width - 4) / Math.max(1, control.model.length)
        y: 2
        width: (control.width - 4) / Math.max(1, control.model.length)
        height: control.height - 4
        radius: 8
        color: control.theme.primary
        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
    }
    Row {
        anchors.fill: parent
        anchors.margins: 2
        Repeater {
            model: control.model
            Button {
                id: segment
                objectName: "segment" + index
                required property int index
                required property var modelData
                width: (control.width - 4) / Math.max(1, control.model.length)
                height: control.height - 4
                padding: 0
                hoverEnabled: true
                readonly property bool selected: control.currentIndex === index
                Accessible.checkable: true
                Accessible.checked: selected
                Accessible.name: String(modelData)
                contentItem: Text {
                    text: String(segment.modelData)
                    color: segment.selected ? control.theme.primaryText : control.theme.secondary
                    font.pixelSize: control.textSize
                    font.weight: segment.selected ? Font.DemiBold : Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 8
                    color: segment.hovered && !segment.selected ? control.theme.hover : "transparent"
                    border.color: control.theme.primary
                    border.width: segment.visualFocus ? 2 : 0
                }
                onClicked: control.activated(index)
            }
        }
    }
}
