import QtQuick

QtObject {
    property int mode: 4
    property int style: 2
    readonly property bool dark: mode !== 5
    readonly property var names: ["微光紫", "深海蓝", "松石绿", "暖陶橙", "石墨灰", "云雾白"]
    readonly property var styleNames: ["鲜明", "染色", "柔和", "单色"]
    readonly property var seeds: ["#ba91f4", "#6cc7f2", "#73d8b2", "#f5af7b", "#82aaff", "#3768cf"]
    readonly property color seed: seeds[Math.max(0, Math.min(5, mode))]
    readonly property color primary: style === 3 ? (dark ? "#e6e8ed" : "#292d35")
                                               : (style === 2 ? blend(seed, dark ? "#c6cad3" : "#747c8c", 0.28) : seed)
    readonly property color primaryText: luminance(primary) > 0.179 ? "#151920" : "#ffffff"
    readonly property real surfaceTint: style === 1 ? 0.11 : 0
    readonly property color workspace: blend(dark ? "#14161a" : "#eceef2", seed, surfaceTint)
    readonly property color surface: blend(dark ? "#22252b" : "#fafbfd", seed, surfaceTint)
    readonly property color block: blend(dark ? "#2c3037" : "#eef0f4", seed, surfaceTint)
    readonly property color raised: blend(dark ? "#363b44" : "#ffffff", seed, surfaceTint)
    readonly property color text: dark ? "#eef0f5" : "#232730"
    readonly property color secondary: dark ? "#adb4c1" : "#5d6675"
    readonly property color muted: dark ? "#8992a2" : "#737d8d"
    readonly property color line: alpha(text, dark ? 0.075 : 0.09)
    readonly property color hover: alpha(text, dark ? 0.07 : 0.045)
    readonly property color selection: alpha(primary, dark ? 0.15 : 0.10)
    readonly property color success: dark ? "#80cca1" : "#267349"
    readonly property color warning: dark ? "#edbe7b" : "#956214"
    readonly property color danger: dark ? "#ed8b91" : "#bf3e48"
    readonly property color shellStart: alpha(surface, 0.38)
    readonly property color shellEnd: alpha(workspace, 0.38)

    function alpha(color: color, opacity: real): color {
        return Qt.rgba(color.r, color.g, color.b, opacity)
    }
    function blend(first: color, second: color, amount: real): color {
        return Qt.rgba(first.r * (1 - amount) + second.r * amount,
                       first.g * (1 - amount) + second.g * amount,
                       first.b * (1 - amount) + second.b * amount, 1)
    }
    function luminance(color: color): real {
        function linear(value) { return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4) }
        return linear(color.r) * 0.2126 + linear(color.g) * 0.7152 + linear(color.b) * 0.0722
    }
}
