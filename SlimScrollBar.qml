import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T

T.ScrollBar {
    id: bar
    required property AppTheme theme
    width: 8
    padding: 1
    orientation: Qt.Vertical
    policy: ScrollBar.AsNeeded
    hoverEnabled: true
    minimumSize: Math.min(1, 28 / Math.max(28, height))
    opacity: size < 1 ? 1 : 0
    background: Rectangle {
        radius: 4
        color: bar.theme.alpha(bar.theme.secondary, bar.hovered || bar.pressed ? 0.08 : 0.025)
    }
    contentItem: Rectangle {
        implicitWidth: 4
        implicitHeight: 28
        radius: width / 2
        color: bar.theme.secondary
        opacity: bar.pressed ? 0.85 : bar.hovered ? 0.65 : 0.35
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
