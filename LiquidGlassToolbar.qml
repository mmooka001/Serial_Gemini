import QtQuick

Item {
    id: control

    required property Item sourceItem
    property rect sourceRect: Qt.rect(0, 0, width, height)
    property color baseColor: "#25292e"
    property bool dark: true
    property int currentIndex: 0
    property int count: 4
    property real itemHeight: 48
    property real spacing: 4
    readonly property bool dragging: pointer.pressed && held
    readonly property int hoveredIndex: pointer.containsMouse ? indexAt(pointer.mouseY) : -1
    readonly property int pressedIndex: pointer.pressed ? pressIndex : -1
    readonly property int previewIndex: dragging ? indexAt(pointer.mouseY) : currentIndex
    signal activated(int index, bool toggle)

    property bool held: false
    property int pressIndex: -1
    property bool initialized: false
    property bool settled: true
    property real pointerX: width / 2
    property real pointerY: itemHeight / 2
    property real centerX: width / 2
    property real centerY: itemHeight / 2
    property real velocityX: 0
    property real velocityY: 0
    property real stretch: 0
    property real bendX: 0
    property real bendY: 0
    property real lift: 0
    property int restIndex: 0
    readonly property real targetX: dragging ? width / 2 + Math.max(-2.5, rubberBand(pointerX - width / 2, 11)) : width / 2
    readonly property real targetY: dragging ? constrainedY(pointerY)
                                            : (currentIndex >= 0 ? currentIndex : restIndex) * (itemHeight + spacing) + itemHeight / 2
    readonly property real bubbleWidth: Math.max(1, width - 8) * (1 - stretch * 0.4) * (1 + lift * 0.02)
    readonly property real bubbleHeight: (itemHeight - 4) * (1 + stretch) * (1 + lift * 0.02)

    function indexAt(y: real): int {
        return Math.max(0, Math.min(count - 1, Math.floor((y + spacing / 2) / (itemHeight + spacing))))
    }
    function rubberBand(distance: real, limit: real): real {
        return distance / (1 + Math.abs(distance) / limit)
    }
    function constrainedY(y: real): real {
        var minimum = itemHeight / 2
        var maximum = Math.max(0, count - 1) * (itemHeight + spacing) + minimum
        if (y < minimum) return minimum + rubberBand(y - minimum, 9)
        if (y > maximum) return maximum + rubberBand(y - maximum, 9)
        return y
    }
    function wake() {
        if (initialized) settled = false
    }
    function cancelDrag() {
        held = false
        pressIndex = -1
        wake()
    }
    function advance(dt: real) {
        // 小步积分的阻尼弹簧：快速跟手，松手保留少量惯性。
        dt = Math.max(0.001, Math.min(dt, 0.032))
        var steps = Math.ceil(dt / 0.008)
        var step = dt / steps
        var stiffness = dragging ? 340 : 300
        var damping = dragging ? 28 : 26
        for (var i = 0; i < steps; ++i) {
            velocityX += ((targetX - centerX) * stiffness - velocityX * damping) * step
            velocityY += ((targetY - centerY) * stiffness - velocityY * damping) * step
            centerX += velocityX * step
            centerY += velocityY * step
        }
        // 速度与弹簧张力共同驱动轻微的拉伸、挤压和不对称弯曲。
        var tension = targetY - centerY
        var desiredStretch = Math.max(-0.025, Math.min(0.075, Math.abs(velocityY) / 8000 + tension / 1200))
        var smoothing = 1 - Math.exp(-dt * 17)
        lift += ((dragging ? 1 : 0) - lift) * smoothing
        stretch += (desiredStretch - stretch) * smoothing
        bendX += (Math.max(-0.07, Math.min(0.07, (targetX - centerX) / 120)) - bendX) * smoothing
        bendY += (Math.max(-0.065, Math.min(0.065, velocityY / 10000)) - bendY) * smoothing
        if (!dragging && Math.abs(targetX - centerX) < 0.025 && Math.abs(targetY - centerY) < 0.025
                && Math.abs(velocityX) + Math.abs(velocityY) < 0.12
                && Math.abs(stretch) + Math.abs(bendX) + Math.abs(bendY) + Math.abs(lift) < 0.001) {
            centerX = targetX
            centerY = targetY
            velocityX = 0
            velocityY = 0
            stretch = 0
            bendX = 0
            bendY = 0
            lift = 0
            settled = true
        }
    }
    onTargetXChanged: wake()
    onTargetYChanged: wake()
    onDraggingChanged: wake()
    onCurrentIndexChanged: if (currentIndex >= 0) restIndex = currentIndex
    Component.onCompleted: {
        centerX = targetX
        centerY = targetY
        if (currentIndex >= 0) restIndex = currentIndex
        initialized = true
    }

    FrameAnimation {
        running: control.visible && !control.settled
        onTriggered: control.advance(frameTime)
    }
    Connections {
        target: control.Window.window
        function onActiveChanged() {
            if (target && !target.active) control.cancelDrag()
        }
    }

    // 留出折射与回弹余量；背景采样同步扩展，不将气泡裁在工具栏边缘。
    LiquidGlassSelection {
        x: -12; y: -12
        width: control.width + 24
        height: control.height + 24
        sourceItem: control.sourceItem
        sourceRect: Qt.rect(control.sourceRect.x - 12, control.sourceRect.y - 12,
                            control.sourceRect.width + 24, control.sourceRect.height + 24)
        fixedRect: Qt.rect(control.centerX + 12 - control.bubbleWidth / 2,
                           control.centerY + 12 - control.bubbleHeight / 2,
                           control.bubbleWidth, control.bubbleHeight)
        selectedIndex: 0
        opacity: control.dragging || control.currentIndex >= 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        baseColor: control.baseColor
        dark: control.dark
        animationsEnabled: false
        deformation: Qt.vector2d(control.bendX, control.bendY)
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        pressAndHoldInterval: 320
        cursorShape: control.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onPressed: (mouse) => {
            control.pressIndex = control.indexAt(mouse.y)
            control.pointerX = mouse.x
            control.pointerY = mouse.y
        }
        onPressAndHold: (mouse) => {
            control.pointerX = mouse.x
            control.pointerY = mouse.y
            control.held = true
        }
        onPositionChanged: (mouse) => {
            if (!control.dragging) return
            control.pointerX = mouse.x
            control.pointerY = mouse.y
        }
        onReleased: (mouse) => {
            var wasDragging = control.held
            var index = wasDragging ? control.indexAt(mouse.y) : control.pressIndex
            control.held = false
            control.pressIndex = -1
            if (wasDragging || containsMouse) control.activated(index, !wasDragging)
            control.wake()
        }
        onCanceled: control.cancelDrag()
    }
}
