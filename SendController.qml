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
    readonly property string encoding: backend.dataEncoding
    readonly property var hexInput: hexMode ? backend.prepareHexInput(inputText) : ({valid: true, containsText: false, error: ""})
    readonly property string hexInputError: hexMode && inputText.length > 0 && !hexInput.valid ? hexInput.error : ""
    readonly property string conversionNotice: "引号内文本将转换为" + encoding + "的 HEX 编码发送"
    readonly property bool needsConversion: hexMode && hexInput.valid && hexInput.containsText
    signal inputConverted(string hex)
    onInputTextChanged: notice = ""
    onEncodingChanged: notice = ""

    function validate(): bool {
        if (!backend.isOpen) { notice = "请先连接串口。"; return false }
        if (!inputText.length) { notice = "请输入要发送的内容。"; return false }
        if (hexInputError.length) { notice = hexInputError; return false }
        notice = ""
        return true
    }
    function preparedInput(): string {
        if (!needsConversion) return inputText
        var hex = hexInput.hex
        inputConverted(hex)
        notice = conversionNotice
        return hex
    }
    function sendOnce(): bool {
        if (!validate()) return false
        var payload = preparedInput()
        if (checksumType > 0) backend.sendDataWithChecksum(payload, hexMode, checksumType)
        else backend.sendData(payload, hexMode)
        return true
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
        backend.sendData(payload, hex)
        return true
    }
    function toggleRepeat() {
        if (running) { running = false; return }
        if (!validate()) return
        preparedInput()
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
