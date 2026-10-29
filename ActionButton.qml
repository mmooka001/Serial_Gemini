import QtQuick
import QtQuick.Controls

Button {
    id: control
    required property AppTheme theme
    property string kind: "quiet"
    property string glyph: ""
    property bool selected: false
    property string hint: ""
    property bool leftAligned: false
    readonly property color foreground: !enabled ? theme.muted
        : kind === "primary" ? theme.primaryText
        : kind === "accent" ? theme.primary
        : kind === "danger" ? theme.danger
        : selected ? theme.primary : theme.secondary

    implicitHeight: 30
    implicitWidth: Math.max(30, contentItem.implicitWidth + leftPadding + rightPadding)
    leftPadding: 10
    rightPadding: 10
    topPadding: 0
    bottomPadding: 0
    hoverEnabled: true
    font.pixelSize: 11
    font.weight: Font.Medium
    opacity: enabled ? 1 : 0.5
    scale: down ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    ToolTip.visible: hovered && hint.length > 0
    ToolTip.text: hint
    ToolTip.delay: 650
    Accessible.name: text.length > 0 ? text : hint

    contentItem: Item {
        implicitWidth: buttonRow.implicitWidth
        implicitHeight: buttonRow.implicitHeight
        Row {
            id: buttonRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: control.leftAligned ? undefined : parent.horizontalCenter
            anchors.left: control.leftAligned ? parent.left : undefined
            spacing: 6
            Text {
                visible: control.glyph.length > 0
                text: control.glyph
                font.family: "Segoe Fluent Icons"
                font.pixelSize: 13
                height: 18
                verticalAlignment: Text.AlignVCenter
                color: control.foreground
            }
            Text {
                visible: control.text.length > 0
                text: control.text
                font: control.font
                height: 18
                verticalAlignment: Text.AlignVCenter
                color: control.foreground
            }
        }
    }
    background: Rectangle {
        radius: Math.min(10, height / 2)
        color: control.kind === "primary" ? control.theme.primary
             : control.kind === "danger" && (control.selected || control.hovered) ? control.theme.alpha(control.theme.danger, 0.12)
             : control.selected ? control.theme.selection
             : control.down || control.hovered ? control.theme.hover
             : control.kind === "tonal" ? control.theme.block : "transparent"
        border.width: control.visualFocus ? 2 : 0
        border.color: control.theme.primary
        opacity: control.kind === "primary" && control.hovered ? 0.88 : 1
        Behavior on color { ColorAnimation { duration: 140 } }
    }
}
