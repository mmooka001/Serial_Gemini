import QtQuick

MouseArea {
    id: dragArea
    required property Window targetWindow
    required property WindowStateController stateController
    readonly property rect normalGeometry: stateController.normalGeometry
    property point pressPosition
    property real horizontalAnchor: 0.5
    property real verticalAnchor: 21
    property bool moveStarted: false
    readonly property bool edgeToEdge: targetWindow.visibility === Window.Maximized
                                        || targetWindow.visibility === Window.FullScreen
    acceptedButtons: Qt.LeftButton
    preventStealing: true

    function rememberGeometry() {
        stateController.rememberGeometry()
    }
    function restoreForDrag(position: point) {
        if (!edgeToEdge) return
        stateController.restoreForDrag(position, horizontalAnchor, verticalAnchor)
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
        stateController.toggleMaximized()
    }
}
