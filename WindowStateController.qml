import QtQuick

QtObject {
    id: controller
    required property Window targetWindow
    property rect normalGeometry: Qt.rect(0, 0, 1250, 850)
    property int preferredVisibility: Window.Windowed
    property int lastVisibleMode: Window.Windowed
    property bool ready: false
    property bool restoring: false
    property bool resumePending: false

    function isRestorable(mode: int): bool {
        return mode === Window.Windowed || mode === Window.Maximized || mode === Window.FullScreen
    }
    function applyGeometry() {
        targetWindow.width = Math.max(targetWindow.minimumWidth, normalGeometry.width)
        targetWindow.height = Math.max(targetWindow.minimumHeight, normalGeometry.height)
        targetWindow.x = normalGeometry.x
        targetWindow.y = normalGeometry.y
    }
    function rememberGeometry() {
        if (!ready || restoring || resumePending || targetWindow.visibility !== Window.Windowed) return
        normalGeometry = Qt.rect(targetWindow.x, targetWindow.y, targetWindow.width, targetWindow.height)
    }
    function initialize() {
        if (!isRestorable(preferredVisibility)) preferredVisibility = Window.Windowed
        ready = true
        Qt.callLater(() => showPreferred())
    }
    function showPreferred() {
        restoring = true
        geometryTimer.stop()
        if (preferredVisibility === Window.Maximized) targetWindow.showMaximized()
        else if (preferredVisibility === Window.FullScreen) targetWindow.showFullScreen()
        else {
            targetWindow.showNormal()
            applyGeometry()
        }
        lastVisibleMode = preferredVisibility
        settleTimer.restart()
    }
    function minimize() {
        rememberGeometry()
        if (isRestorable(targetWindow.visibility)) preferredVisibility = targetWindow.visibility
        lastVisibleMode = preferredVisibility
        resumePending = true
        geometryTimer.stop()
        targetWindow.showMinimized()
    }
    function toggleMaximized() {
        rememberGeometry()
        preferredVisibility = targetWindow.visibility === Window.Maximized || targetWindow.visibility === Window.FullScreen
                              ? Window.Windowed : Window.Maximized
        showPreferred()
    }
    function restoreForDrag(position: point, horizontalAnchor: real, verticalAnchor: real) {
        preferredVisibility = Window.Windowed
        restoring = true
        targetWindow.showNormal()
        applyGeometry()
        targetWindow.x = Math.round(position.x - targetWindow.width * horizontalAnchor)
        targetWindow.y = Math.round(position.y - verticalAnchor)
        lastVisibleMode = Window.Windowed
        settleTimer.restart()
    }
    property Timer geometryTimer: Timer {
        interval: 200
        onTriggered: controller.rememberGeometry()
    }
    property Timer settleTimer: Timer {
        interval: 80
        onTriggered: {
            controller.restoring = false
            if (controller.targetWindow.visibility === Window.Windowed) controller.geometryTimer.restart()
        }
    }
    property Timer resumeTimer: Timer {
        interval: 0
        onTriggered: {
            controller.resumePending = false
            controller.showPreferred()
        }
    }
    property Connections watcher: Connections {
        target: controller.targetWindow
        function onXChanged() { controller.geometryTimer.restart() }
        function onYChanged() { controller.geometryTimer.restart() }
        function onWidthChanged() { controller.geometryTimer.restart() }
        function onHeightChanged() { controller.geometryTimer.restart() }
        function onVisibilityChanged() {
            if (!controller.ready) return
            var mode = target.visibility
            if (mode === Window.Minimized) {
                controller.geometryTimer.stop()
                controller.settleTimer.stop()
                controller.restoring = false
                if (!controller.resumePending) {
                    controller.preferredVisibility = controller.lastVisibleMode
                    controller.resumePending = true
                }
            } else if (controller.restoring) {
                return
            } else if (controller.resumePending && controller.isRestorable(mode)) {
                controller.resumeTimer.restart()
            } else if (controller.isRestorable(mode)) {
                controller.preferredVisibility = mode
                controller.lastVisibleMode = mode
                controller.geometryTimer.restart()
            }
        }
    }
}
