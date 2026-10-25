import QtQuick

QtObject {
    id: controller
    property int minimumWidth: 180
    property int maximumWidth: 1000
    property int collapseDistance: 48
    property int edgeHoldDuration: 450
    property bool active: false
    property bool collapsed: false
    property real startWidth: 0
    property real requestedWidth: 0
    property bool edgeReady: false
    signal widthRequested(int width)

    function begin(width: real) {
        edgeTimer.stop()
        collapsed = false
        edgeReady = false
        startWidth = width
        requestedWidth = width
        active = true
    }
    function move(delta: real) {
        if (!active) return
        requestedWidth = startWidth + delta
        if (collapsed) {
            if (requestedWidth >= minimumWidth) {
                collapsed = false
                edgeReady = false
                widthRequested(Math.round(Math.min(maximumWidth, requestedWidth)))
            }
            return
        }
        widthRequested(Math.round(Math.max(minimumWidth, Math.min(maximumWidth, requestedWidth))))
        if (requestedWidth > minimumWidth) {
            edgeTimer.stop()
            edgeReady = false
        } else {
            if (!edgeReady && !edgeTimer.running) edgeTimer.start()
            tryCollapse()
        }
    }
    function tryCollapse() {
        if (active && edgeReady && requestedWidth <= minimumWidth - collapseDistance)
            collapsed = true
    }
    function end() {
        edgeTimer.stop()
        edgeReady = false
        active = false
    }
    property Timer edgeTimer: Timer {
        interval: controller.edgeHoldDuration
        onTriggered: {
            controller.edgeReady = true
            controller.tryCollapse()
        }
    }
}
