import QtQuick
import QtTest
import "../.." as App

TestCase {
    id: testCase
    name: "SendWorkflow"
    width: 520; height: 420
    visible: true
    when: windowShown
    App.AppTheme { id: theme }
    QtObject {
        id: backend
        property bool isOpen: true
        property int count: 0
        property string lastPayload: ""
        property bool lastHex: false
        property int checksum: 0
        property string dataEncoding: "UTF-8"
        function isHexInput(text) { return /^(?:[0-9a-fA-F]{2})+$/.test(text.replace(/0x/gi, "").replace(/\s+/g, "")) }
        function textToHex(text) { return text.split("").map(ch => ch.charCodeAt(0).toString(16).padStart(2, "0")).join(" ").toUpperCase() }
        function sendData(text, hex) { count++; lastPayload = text; lastHex = hex; checksum = 0 }
        function sendDataWithChecksum(text, hex, type) { sendData(text, hex); checksum = type }
    }
    App.SendController {
        id: sender
        backend: backend
        onInputConverted: (hex) => inputText = hex
    }
    property int commandInterval: 500
    App.IntervalField {
        id: manualInterval
        theme: theme
        x: 20; y: 300
        interval: sender.interval
        onIntervalEdited: (milliseconds) => sender.interval = milliseconds
    }
    App.IntervalField {
        id: commandIntervalButton
        theme: theme
        x: 180; y: 300
        interval: testCase.commandInterval
        onIntervalEdited: (milliseconds) => testCase.commandInterval = milliseconds
    }
    function init() { failOnWarning(/.*/) }
    function cleanup() {
        sender.running = false
        sender.inputText = ""
        sender.hexMode = true
        sender.interval = 500
        sender.checksumType = 0
        backend.isOpen = true
        backend.dataEncoding = "UTF-8"
        backend.count = 0
        backend.lastPayload = ""
        testCase.commandInterval = 500
    }
    function test_asciiConvertsOnceWithoutChangingHexMode() {
        sender.inputText = "AT+RST"
        verify(sender.needsConversion)
        verify(sender.sendOnce())
        compare(sender.inputText, "41 54 2B 52 53 54")
        compare(backend.lastPayload, sender.inputText)
        compare(backend.lastHex, true)
        compare(sender.hexMode, true)
        compare(sender.notice, "检测到非hex内容，该内容将转换为UTF-8的hex编码发送")
        verify(sender.sendOnce())
        compare(backend.lastPayload, "41 54 2B 52 53 54")
    }
    function test_conversionHintTracksSelectedEncoding() {
        sender.inputText = "AT+RST"
        verify(sender.needsConversion)
        for (var encoding of ["UTF-8", "GBK", "GB2312", "ASCII", "ISO-8859-1"]) {
            backend.dataEncoding = encoding
            compare(sender.conversionNotice, "检测到非hex内容，该内容将转换为" + encoding + "的hex编码发送")
            verify(sender.sendPreset("AT+RST", false))
            compare(sender.notice, sender.conversionNotice)
        }
        backend.dataEncoding = "UTF-8"
        compare(sender.notice, "")
    }
    function test_textAndRawHexStayInTheirChosenMode() {
        sender.hexMode = false
        sender.inputText = "AT+RST"
        verify(sender.sendOnce())
        compare(backend.lastPayload, "AT+RST")
        compare(backend.lastHex, false)
        sender.hexMode = true
        sender.inputText = "AA 55 00"
        sender.checksumType = 2
        verify(sender.sendOnce())
        compare(backend.lastPayload, "AA 55 00")
        compare(backend.checksum, 2)
    }
    function test_asciiPresetUsesHexWithoutChangingItsSourceOrMode() {
        var source = "AB"
        sender.inputText = "48"
        sender.hexMode = true
        verify(sender.sendPreset(source, false))
        compare(backend.lastPayload, "41 42")
        compare(backend.lastHex, true)
        compare(source, "AB")
        compare(sender.inputText, "48")
        compare(sender.hexMode, true)
        verify(sender.sendPreset("AA 55", true))
        compare(backend.lastPayload, "AA 55")
        compare(sender.hexMode, true)
        sender.hexMode = false
        verify(sender.sendPreset("AT+RST", false))
        compare(backend.lastPayload, "AT+RST")
        compare(backend.lastHex, false)
        verify(sender.sendPreset("AA 55", true))
        compare(backend.lastPayload, "AA 55")
        compare(sender.hexMode, false)
    }
    function test_disconnectedOrEmptyCannotStartRepeat() {
        backend.isOpen = false
        sender.inputText = "41"
        sender.toggleRepeat()
        compare(sender.running, false)
        compare(backend.count, 0)
        backend.isOpen = true
        sender.inputText = ""
        sender.toggleRepeat()
        compare(sender.running, false)
    }
    function test_repeatStopsOnDisconnectAndUsesOwnInterval() {
        sender.inputText = "41"
        sender.interval = 60
        sender.toggleRepeat()
        tryVerify(() => backend.count >= 2, 500)
        compare(testCase.commandInterval, 500)
        backend.isOpen = false
        compare(sender.running, false)
        var count = backend.count
        wait(100)
        compare(backend.count, count)
    }
    function test_intervalEntryCommitsAndIsIndependent() {
        var field = findChild(manualInterval, "millisecondsInput")
        mouseClick(field, field.width / 2, field.height / 2)
        tryCompare(field, "selectedText", "500")
        field.remove(0, field.length)
        field.insert(0, "1250")
        keyClick(Qt.Key_Return)
        compare(sender.interval, 1250)
        compare(testCase.commandInterval, 500)
        commandIntervalButton.intervalEdited(900)
        compare(sender.interval, 1250)
        compare(testCase.commandInterval, 900)
        compare(findChild(manualInterval, "intervalPopup"), null)
    }
    function test_intervalBlurCommitsAndInvalidValueReverts() {
        var field = findChild(manualInterval, "millisecondsInput")
        field.forceActiveFocus()
        field.remove(0, field.length)
        field.insert(0, "800")
        commandIntervalButton.forceActiveFocus()
        compare(sender.interval, 800)
        field.forceActiveFocus()
        field.remove(0, field.length)
        field.insert(0, "9")
        commandIntervalButton.forceActiveFocus()
        compare(sender.interval, 800)
        compare(field.text, "800")
    }
    function test_intervalEscapeCancelsEdit() {
        var field = findChild(manualInterval, "millisecondsInput")
        field.forceActiveFocus()
        field.remove(0, field.length)
        field.insert(0, "900")
        keyClick(Qt.Key_Escape)
        compare(sender.interval, 500)
        compare(field.text, "500")
    }
}
