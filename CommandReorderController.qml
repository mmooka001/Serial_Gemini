import QtQuick

QtObject {
    id: controller
    required property Item surface
    required property var view
    property Item sourceCard: null
    property Item column: null
    property var repeater: null
    property int groupIndex: -1
    property int sourceIndex: -1
    property int targetIndex: -1
    property point scenePosition
    property real grabOffset: 0
    property real ghostX: 0
    property real ghostY: 0
    property real ghostWidth: 0
    property real ghostHeight: 0
    property real markerY: 0
    property string name: ""
    property string payload: ""
    readonly property bool active: sourceCard !== null
    signal moveRequested(int group, int from, int to, string name, string payload)

    function begin(group: int, index: int, column: Item, repeater, card: Item, position: point) {
        controller.column = column
        controller.repeater = repeater
        groupIndex = group
        sourceIndex = index
        targetIndex = index
        sourceCard = card
        var origin = card.mapToItem(surface, 0, 0)
        var cursor = surface.mapFromItem(null, position.x, position.y)
        grabOffset = cursor.y - origin.y
        ghostX = origin.x
        ghostWidth = card.width
        ghostHeight = card.height
        name = card.draftName
        payload = card.draftPayload
        move(position)
    }
    function move(position: point) {
        if (!active) return
        scenePosition = position
        var local = column.mapFromItem(null, position.x, position.y)
        var insertion = 0
        for (var i = 0; i < repeater.count; ++i) {
            var item = repeater.itemAt(i)
            if (item && local.y > item.y + item.height / 2) insertion = i + 1
        }
        targetIndex = Math.max(0, Math.min(repeater.count - 1, insertion > sourceIndex ? insertion - 1 : insertion))
        var edgeItem = repeater.itemAt(Math.min(insertion, repeater.count - 1))
        if (edgeItem) {
            var edge = edgeItem.mapToItem(surface, 0, insertion === repeater.count ? edgeItem.height + 3 : -3)
            markerY = edge.y
        }
        var cursor = surface.mapFromItem(null, position.x, position.y)
        ghostY = cursor.y - grabOffset
    }
    function finish(position: point, name: string, payload: string) {
        if (!active) return
        move(position)
        var group = groupIndex, from = sourceIndex, to = targetIndex
        var card = sourceCard
        cancel()
        if (from !== to) moveRequested(group, from, to, name, payload)
        else Qt.callLater(card.flushCommit)
    }
    function cancel() {
        var card = sourceCard
        sourceCard = null
        if (card) card.reorderHeld = false
        column = null
        repeater = null
    }
    function remapSelection(selected, group: int, from: int, to: int) {
        var result = {}
        for (var key in selected) {
            var parts = key.split(":"), index = Number(parts[1])
            if (Number(parts[0]) === group) {
                if (index === from) index = to
                else if (from < to && index > from && index <= to) --index
                else if (from > to && index >= to && index < from) ++index
                key = group + ":" + index
            }
            result[key] = selected[parts.join(":")]
        }
        return result
    }
    property Timer autoScroll: Timer {
        interval: 16
        repeat: true
        running: controller.active
        onTriggered: {
            var local = controller.view.mapFromItem(null, controller.scenePosition.x, controller.scenePosition.y)
            var delta = local.y < 32 ? -6 : local.y > controller.view.height - 32 ? 6 : 0
            if (!delta) return
            var top = controller.column.mapToItem(controller.view.contentItem, 0, 0).y
            var minimum = Math.max(0, top - controller.view.height + 32)
            var maximum = Math.max(minimum, Math.min(controller.view.contentHeight - controller.view.height,
                                                     top + controller.column.height - 32))
            controller.view.contentY = Math.max(minimum, Math.min(maximum, controller.view.contentY + delta))
            controller.move(controller.scenePosition)
        }
    }
}
