import QtQuick
import QtTest
import "../.." as App

TestCase {
    id: testCase
    name: "WindowDrag"
    when: windowShown
    width: 640; height: 480
    visible: true
    Window {
        id: target
        width: 500; height: 360
        minimumWidth: 300; minimumHeight: 240
        visible: true
        flags: Qt.Window | Qt.FramelessWindowHint
        App.WindowStateController {
            id: windowState
            targetWindow: target
            normalGeometry: Qt.rect(0, 0, 500, 360)
        }
        App.WindowDragArea {
            id: dragArea
            anchors.fill: parent
            targetWindow: target
            stateController: windowState
        }
    }
    function init() {
        failOnWarning(/.*/)
        windowState.preferredVisibility = Window.Windowed
        windowState.normalGeometry = Qt.rect(120, 140, 500, 360)
        windowState.initialize()
        tryVerify(() => target.visibility === Window.Windowed
                     && target.x === 120 && target.y === 140
                     && target.width === 500 && target.height === 360
                     && !windowState.restoring)
    }
    function test_maximizedDragRestoresSizeStateAndPointerAnchor() {
        target.showMaximized()
        tryCompare(target, "visibility", Window.Maximized)
        compare(dragArea.edgeToEdge, true)
        dragArea.horizontalAnchor = 0.6
        dragArea.verticalAnchor = 21
        dragArea.restoreForDrag(Qt.point(450, 180))
        tryCompare(target, "visibility", Window.Windowed)
        compare(target.width, 500)
        compare(target.height, 360)
        compare(target.x, 150)
        compare(target.y, 159)
        compare(dragArea.edgeToEdge, false)
    }
    function test_fullScreenDragRestoresWindowedState() {
        target.showFullScreen()
        tryCompare(target, "visibility", Window.FullScreen)
        dragArea.restoreForDrag(Qt.point(320, 200))
        tryCompare(target, "visibility", Window.Windowed)
        compare(target.width, 500)
        compare(target.height, 360)
        compare(dragArea.edgeToEdge, false)
    }
    function test_clickDoesNotRestoreMaximizedWindow() {
        target.showMaximized()
        tryCompare(target, "visibility", Window.Maximized)
        mouseClick(dragArea, 100, 21)
        compare(target.visibility, Window.Maximized)
    }
    function test_repeatedStateChangesPreserveNormalGeometry() {
        for (const mode of [Window.Maximized, Window.FullScreen, Window.Maximized]) {
            windowState.preferredVisibility = mode
            windowState.showPreferred()
            tryCompare(target, "visibility", mode)
            windowState.toggleMaximized()
            tryVerify(() => target.visibility === Window.Windowed
                         && target.x === 120 && target.y === 140
                         && target.width === 500 && target.height === 360)
        }
    }
}
