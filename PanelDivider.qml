import QtQuick

MouseArea {
    id: divider
    property bool vertical: true
    property color accentColor: "#82aaff"
    property real pressPosition: 0
    signal resizeStarted()
    signal resizeMoved(real delta)
    signal resizeFinished()
    hoverEnabled: true
    preventStealing: true
    cursorShape: vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor

    onPressed: (mouse) => {
        var position = mapToItem(null, mouse.x, mouse.y)
        pressPosition = vertical ? position.x : position.y
        resizeStarted()
    }
    onPositionChanged: (mouse) => {
        if (!pressed) return
        var position = mapToItem(null, mouse.x, mouse.y)
        resizeMoved((vertical ? position.x : position.y) - pressPosition)
    }
    onReleased: resizeFinished()
    onCanceled: resizeFinished()

    Rectangle {
        objectName: "dividerHighlight"
        anchors.centerIn: parent
        width: divider.vertical ? 3 : Math.min(64, parent.width * 0.25)
        height: divider.vertical ? Math.min(64, parent.height * 0.25) : 3
        radius: 1.5
        color: divider.accentColor
        opacity: divider.pressed ? 0.9 : (divider.containsMouse ? 0.5 : 0)
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
