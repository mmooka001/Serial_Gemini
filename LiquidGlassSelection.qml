import QtQuick

// 共用一个透镜，采样按钮内容；位置只由选中项驱动。
Item {
    id: root

    required property Item sourceItem
    property Item selectedItem: null
    property int selectedIndex: 0
    property bool dark: true
    property bool ready: false
    property Item lastSelectedItem: null
    readonly property rect selectionRect: {
        if (!lastSelectedItem)
            return Qt.rect(4, 2, width - 8, 44)
        var origin = lastSelectedItem.mapToItem(root, 0, 0)
        return Qt.rect(origin.x + 4, origin.y + 2,
                       lastSelectedItem.width - 8, lastSelectedItem.height - 4)
    }

    onSelectedItemChanged: {
        if (selectedItem)
            lastSelectedItem = selectedItem
    }
    Component.onCompleted: {
        if (selectedItem)
            lastSelectedItem = selectedItem
        ready = true
    }

    ShaderEffectSource {
        id: buttonTexture
        sourceItem: root.sourceItem
        hideSource: true
        visible: false
        live: true
        textureSize: Qt.size(Math.ceil(root.width * Screen.devicePixelRatio),
                             Math.ceil(root.height * Screen.devicePixelRatio))
    }

    ShaderEffect {
        anchors.fill: parent
        property var source: buttonTexture
        property vector2d surfaceSize: Qt.vector2d(width, height)
        property real lensY: root.selectionRect.y
        property real lensHeight: root.selectionRect.height
        property real lensX: root.selectionRect.x
        property real lensWidth: root.selectionRect.width
        property real pixelSize: 1 / Screen.devicePixelRatio
        property real presence: root.selectedIndex >= 0 ? 1 : 0
        property real darkMode: root.dark ? 1 : 0
        fragmentShader: "qrc:/shaders/liquidglass.frag.qsb"

        Behavior on lensY {
            enabled: root.ready
            NumberAnimation { duration: 380; easing.type: Easing.OutQuint }
        }
        Behavior on presence {
            enabled: root.ready
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }
}
