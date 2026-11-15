import QtQuick
import QtQuick.Controls

ToolTip {
    id: bubble
    required property AppTheme theme
    delay: 550
    timeout: 5000
    padding: 9
    margins: 8
    y: parent ? -height - 7 : 0
    x: parent ? (parent.width - width) / 2 : 0
    contentItem: Text {
        text: bubble.text
        textFormat: Text.PlainText
        color: bubble.theme.text
        font.pixelSize: bubble.theme.uiPixels(11)
        wrapMode: Text.Wrap
    }
    width: Math.min(338, Math.max(40, implicitWidth))
    background: Rectangle {
        radius: 9
        color: bubble.theme.raised
        border.color: bubble.theme.line
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 110 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 } }
}
