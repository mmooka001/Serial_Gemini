import QtQuick

Item {
    id: layer
    anchors.fill: parent
    z: 10000
    property Item focusRoot: parent

    PointHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        target: null
        onActiveChanged: {
            if (!active || !layer.Window.window) return
            var editor = layer.Window.window.activeFocusItem
            if (!editor || editor === layer.focusRoot) return
            var local = editor.mapFromItem(layer, point.position.x, point.position.y)
            if (!editor.contains(local)) {
                if (typeof editor.deselect === "function") editor.deselect()
                layer.focusRoot.forceActiveFocus()
            }
        }
    }
}
