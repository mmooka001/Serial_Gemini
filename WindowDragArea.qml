import QtQuick

MouseArea {
    id: dragArea
    required property Window targetWindow
    property rect normalGeometry: Qt.rect(0, 0, 1250, 850)
    property point pressPosition
    property real horizontalAnchor: 0.5
    property real verticalAnchor: 21
    property bool moveStarted: false
    readonly property bool edgeToEdge: targetWindow.visibility === Window.Maximized
                                        || targetWindow.visibility === Window.FullScreen
    acceptedButtons: Qt.LeftButton
    preventStealing: true

    function rememberGeometry() {
        if (targetWindow.visibility === Window.Windowed)
            normalGeometry = Qt.rect(targetWindow.x, targetWindow.y, targetWindow.width, targetWindow.height)
    }
    function restoreForDrag(position: point) {
        if (!edgeToEdge) return
        var size = normalGeometry
        targetWindow.showNormal()
        targetWindow.width = Math.max(targetWindow.minimumWidth, size.width)
        targetWindow.height = Math.max(targetWindow.minimumHeight, size.height)
        targetWindow.x = Math.round(position.x - targetWindow.width * horizontalAnchor)
        targetWindow.y = Math.round(position.y - verticalAnchor)
    }
    onPressed: (mouse) => {
        pressPosition = mapToGlobal(mouse.x, mouse.y)
        var local = targetWindow.contentItem.mapFromGlobal(pressPosition.x, pressPosition.y)
        horizontalAnchor = Math.max(0, Math.min(1, local.x / targetWindow.width))
        verticalAnchor = local.y
        moveStarted = false
    }
    onPositionChanged: (mouse) => {
        if (!pressed || moveStarted) return
        var position = mapToGlobal(mouse.x, mouse.y)
        if (Math.abs(position.x - pressPosition.x) + Math.abs(position.y - pressPosition.y)
                < Qt.styleHints.startDragDistance) return
        moveStarted = true
        restoreForDrag(position)
        targetWindow.startSystemMove()
    }
    onDoubleClicked: {
        if (edgeToEdge) targetWindow.showNormal()
        else targetWindow.showMaximized()
    }
    Component.onCompleted: geometryTimer.start()
    Timer {
        id: geometryTimer
        interval: 0
        onTriggered: dragArea.rememberGeometry()
    }
    Connections {
        target: dragArea.targetWindow
        function onXChanged() { geometryTimer.restart() }
        function onYChanged() { geometryTimer.restart() }
        function onWidthChanged() { geometryTimer.restart() }
        function onHeightChanged() { geometryTimer.restart() }
        function onVisibilityChanged() { geometryTimer.restart() }
    }
}
