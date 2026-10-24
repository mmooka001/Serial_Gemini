import QtQuick
import QtQuick.Effects

// 只绘制材质，采样独立的背景层；文字和输入事件由上方的原始控件负责。
Item {
    id: root

    required property Item sourceItem
    property Item selectedItem: null
    property int selectedIndex: 0
    property bool dark: true
    property real horizontalInset: 4
    property real verticalInset: 2
    property int moveDuration: 380
    property color baseColor: dark ? "#222428" : "#f5f6f8"
    property real materialMix: 0.10
    property real blurRadius: 0.7
    property real glassDepth: 7
    property real bevelWidth: 5
    property real cornerRadius: 14
    property real edgeStrength: 1
    property real saturation: 1.2
    property real brightness: dark ? 1.12 : 1
    property real dispersion: 1.4
    property real contentOffsetY: 0
    property rect fixedRect: Qt.rect(0, 0, 0, 0)
    property bool animationsEnabled: true
    property rect sourceRect: Qt.rect(0, 0, width, height)
    property bool ready: false
    property Item lastSelectedItem: null
    readonly property rect selectionRect: {
        if (fixedRect.width > 0 && fixedRect.height > 0)
            return fixedRect
        if (!lastSelectedItem || !lastSelectedItem.parent || !sourceItem)
            return Qt.rect(4, 2, width - 8, 44)
        return Qt.rect(lastSelectedItem.x + horizontalInset,
                       lastSelectedItem.y - contentOffsetY + verticalInset,
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

    Rectangle {
        id: fallbackBackdrop
        width: root.width
        height: root.height
        color: root.baseColor
        visible: false
    }

    ShaderEffectSource {
        id: backdropTexture
        width: root.width
        height: root.height
        sourceItem: root.sourceItem || fallbackBackdrop
        sourceRect: root.sourceItem ? root.sourceRect : Qt.rect(0, 0, root.width, root.height)
        hideSource: false
        visible: false
        live: true
        textureSize: Qt.size(Math.ceil(root.width * Screen.devicePixelRatio),
                             Math.ceil(root.height * Screen.devicePixelRatio))
    }

    // 大范围雾化先走可分离的模糊通道，避免稀疏采样留下背景文字重影。
    MultiEffect {
        id: softBackdrop
        width: root.width
        height: root.height
        source: root.blurRadius > 2 ? backdropTexture : null
        blurEnabled: true
        blurMax: 16
        blur: Math.min(1, root.blurRadius / 16)
        autoPaddingEnabled: false
        visible: false
    }

    ShaderEffectSource {
        id: blurredTexture
        width: root.width
        height: root.height
        sourceItem: root.blurRadius > 2 ? softBackdrop : null
        visible: false
        live: root.blurRadius > 2
        textureSize: backdropTexture.textureSize
    }

    ShaderEffect {
        anchors.fill: parent
        property var source: root.blurRadius > 2 ? blurredTexture : backdropTexture
        property vector2d surfaceSize: Qt.vector2d(width, height)
        property real lensY: root.selectionRect.y
        property real lensHeight: root.selectionRect.height
        property real lensX: root.selectionRect.x
        property real lensWidth: root.selectionRect.width
        property real pixelSize: 1 / Screen.devicePixelRatio
        property real presence: root.selectedIndex >= 0 ? 1 : 0
        property real darkMode: root.dark ? 1 : 0
        property color baseColor: root.baseColor
        property real materialMix: root.materialMix
        property real blurRadius: root.blurRadius > 2 ? 0 : root.blurRadius
        property real glassDepth: root.glassDepth
        property real bevelWidth: root.bevelWidth
        property real cornerRadius: root.cornerRadius
        property real edgeStrength: root.edgeStrength
        property real saturation: root.saturation
        property real brightness: root.brightness
        property real dispersion: root.dispersion
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
