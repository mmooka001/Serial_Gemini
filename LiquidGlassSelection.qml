import QtQuick

// 共用一个透镜，采样选项内容；可由已选项或悬停项驱动。
Item {
    id: root

    required property Item sourceItem
    property Item selectedItem: null
    property int selectedIndex: 0
    property bool dark: true
    property real horizontalInset: 4
    property real verticalInset: 2
    property int moveDuration: 380
    property real magnification: 1.035
    property real glassStrength: 1
    property bool animationsEnabled: true
    property rect sourceRect: Qt.rect(0, 0, width, height)
    property bool ready: false
    property Item lastSelectedItem: null
    readonly property rect selectionRect: {
        if (!lastSelectedItem || !lastSelectedItem.parent || !sourceItem)
            return Qt.rect(4, 2, width - 8, 44)
        var origin = lastSelectedItem.parent.mapToItem(sourceItem,
                                                       lastSelectedItem.x, lastSelectedItem.y)
        return Qt.rect(origin.x - sourceRect.x + horizontalInset,
                       origin.y - sourceRect.y + verticalInset,
                       lastSelectedItem.width - 2 * horizontalInset,
                       lastSelectedItem.height - 2 * verticalInset)
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
        sourceRect: root.sourceRect
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
        property real magnification: root.magnification
        property real glassStrength: root.glassStrength
        fragmentShader: "qrc:/shaders/liquidglass.frag.qsb"

        Behavior on lensY {
            enabled: root.ready && root.animationsEnabled
            NumberAnimation { duration: root.moveDuration; easing.type: Easing.OutQuint }
        }
        Behavior on lensHeight {
            enabled: root.ready && root.animationsEnabled
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on presence {
            enabled: root.ready && root.animationsEnabled
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }
}
