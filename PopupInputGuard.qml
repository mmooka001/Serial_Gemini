import QtQuick
import QtQuick.Controls

Item {
    id: guard
    required property Popup popup
    property Item ownerItem: null
    property bool closeOnWheel: false
    parent: popup.Overlay.overlay
    anchors.fill: parent
    z: 100000

    PointHandler {
        target: null
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onActiveChanged: {
            if (!active || !guard.popup.visible) return
            var position = point.scenePosition
            var origin = guard.popup.contentItem.mapToItem(null, -guard.popup.leftPadding, -guard.popup.topPadding)
            var insidePopup = position.x >= origin.x && position.x <= origin.x + guard.popup.width
                           && position.y >= origin.y && position.y <= origin.y + guard.popup.height
            var insideOwner = false
            if (guard.ownerItem) {
                var local = guard.ownerItem.mapFromItem(null, position.x, position.y)
                insideOwner = guard.ownerItem.contains(local)
            }
            if (!insidePopup && !insideOwner) guard.popup.close()
        }
    }
    WheelHandler {
        enabled: guard.closeOnWheel
        target: null
        onWheel: (event) => {
            event.accepted = false
            guard.popup.close()
        }
    }
}
