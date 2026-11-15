import QtQuick

QtObject {
    id: sender
    required property var backend
    property string inputText: ""
    property bool hexMode: true
    property int checksumType: 0
    property int interval: 500
    property bool running: false
    property string notice: ""
    readonly property int livePreviewLimit: 8192
    readonly property bool previewPending: previewTimer.running
    readonly property string encoding: backend.dataEncoding
    readonly property var hexInput: hexMode && !previewPending ? backend.prepareHexInput(inputText, false)
        : ({valid: true, containsText: false, error: ""})
    readonly property string hexInputError: hexMode && inputText.length > 0 && !hexInput.valid ? hexInput.error : ""
    readonly property string conversionNotice: "引号内文本将转换为" + encoding + "的 HEX 编码发送"
    readonly property bool needsConversion: hexMode && hexInput.valid && hexInput.containsText
    signal inputConverted(string hex)
    onInputTextChanged: {
        notice = ""
        if (inputText.length > livePreviewLimit) previewTimer.restart()
        else previewTimer.stop()
    }
    onEncodingChanged: notice = ""

    property Timer previewTimer: Timer { interval: 180 }

    function validate(parsed): bool {
        if (!backend.isOpen) { notice = "请先连接串口。"; return false }
        if (!inputText.length) { notice = "请输入要发送的内容。"; return false }
        if (!parsed.valid) { notice = parsed.error; return false }
        notice = ""
        return true
    }
    function preparedInput(parsed): string {
        if (!parsed.containsText) return inputText
        // Avoid expanding a large quoted paste into a much larger editable HEX string.
        if (!parsed.hex.length || parsed.hex.length > livePreviewLimit) {
            notice = conversionNotice
            return inputText
        }
        inputConverted(parsed.hex)
        notice = conversionNotice
        return parsed.hex
    }
    function sendOnce(): bool {
        if (!backend.isOpen || !inputText.length) return validate(hexInput)
        const parsed = previewPending && hexMode ? backend.prepareHexInput(inputText, false) : hexInput
        if (!validate(parsed)) return false
        const payload = preparedInput(parsed)
        const accepted = checksumType > 0 ? backend.sendDataWithChecksum(payload, hexMode, checksumType)
                                          : backend.sendData(payload, hexMode)
        return accepted !== false
    }
    function sendPreset(payload: string, presetHex: bool): bool {
        if (!backend.isOpen) { notice = "请先连接串口。"; return false }
        if (!payload.length) { notice = "指令内容为空，请先填写。"; return false }
        notice = ""
        var hex = presetHex || hexMode
        if (presetHex) {
            var parsed = backend.prepareHexInput(payload)
            if (!parsed.valid) { notice = parsed.error; return false }
            if (parsed.containsText) notice = conversionNotice
            payload = parsed.hex
        } else if (hex) {
            payload = backend.textToHex(payload)
            notice = "TXT 指令已按" + encoding + "编码转换为 HEX 发送"
        }
        return backend.sendData(payload, hex) !== false
    }
    function toggleRepeat() {
        if (running) { running = false; return }
        if (!backend.isOpen || !inputText.length) { validate(hexInput); return }
        const parsed = previewPending && hexMode ? backend.prepareHexInput(inputText, false) : hexInput
        if (!validate(parsed)) return
        preparedInput(parsed)
        running = true
    }
    property Timer repeatTimer: Timer {
        interval: sender.interval
        repeat: true
        running: sender.running
        onTriggered: if (!sender.sendOnce()) sender.running = false
    }
    property Connections connectionWatcher: Connections {
        target: sender.backend
        function onIsOpenChanged() {
            if (!sender.backend.isOpen) sender.running = false
            else sender.notice = ""
        }
    }
}
