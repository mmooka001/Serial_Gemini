import QtQuick

QtObject {
    property int minimumWidth: 180
    property int maximumWidth: 1000
    readonly property real collapseDistance: minimumWidth / 2
    property bool active: false
    property bool collapsed: false
    property real startWidth: 0
    property real requestedWidth: 0
    signal widthRequested(int width)

    function begin(width: real) {
        collapsed = false
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
                widthRequested(Math.round(Math.min(maximumWidth, requestedWidth)))
            }
            return
        }
        widthRequested(Math.round(Math.max(minimumWidth, Math.min(maximumWidth, requestedWidth))))
        if (requestedWidth < minimumWidth - collapseDistance)
            collapsed = true
    }
    function end() {
        active = false
    }
}
