import QtQuick
import QtTest
import "../.." as App

TestCase {
    id: testCase
    name: "CommandCard"
    width: 500; height: 450
    visible: true
    when: windowShown
    App.AppTheme { id: cardTheme }
    App.CommandCard {
        id: card
        x: 20; y: 20; width: 220
        theme: cardTheme
        commandName: "连接到设备"
        payload: "AT+MQTT=\"device/command\",\"hello world with a long payload\""
        onEdited: (name, payload) => { commandName = name; card.payload = payload }
        onLoopToggled: loopSelected = !loopSelected
        onFormatToggled: hexMode = !hexMode
    }
    App.FocusDismissLayer { focusRoot: testCase }
    SignalSpy { id: sendSpy; target: card; signalName: "sendRequested" }
    SignalSpy { id: editSpy; target: card; signalName: "edited" }
    SignalSpy { id: deleteSpy; target: card; signalName: "deleteRequested" }
    Component {
        id: refreshingStoreFixture
        Item {
            x: 270; y: 20; width: 210; height: 200
            property var entries: [{name: "示例", payload: "AT"}]
            property int sentCount: 0
            property string sentPayload: ""
            Repeater {
                model: parent.entries
                App.CommandCard {
                    required property var modelData
                    width: 210
                    theme: cardTheme
                    commandName: modelData.name
                    payload: modelData.payload
                    onEdited: (name, payload) => parent.entries = [{name: name, payload: payload}]
                    onSendRequested: (payload, hex) => { parent.sentCount++; parent.sentPayload = payload }
                }
            }
        }
    }
    function init() { failOnWarning(/.*/) }
    function cleanup() {
        testCase.forceActiveFocus()
        findChild(card, "commandActionsPopup").close()
        card.width = 220
        card.payload = "AT+MQTT=\"device/command\",\"hello world with a long payload\""
        card.commandName = "连接到设备"
        card.loopSelected = false
        card.hexMode = false
        sendSpy.clear(); editSpy.clear(); deleteSpy.clear()
    }
    function test_payloadHasFullWidthAndWrapsAtNarrowSizes() {
        var view = findChild(card, "commandPayloadView")
        var editor = findChild(card, "commandPayloadEditor")
        for (var size of [156, 200, 280, 500]) {
            card.width = size
            tryCompare(view, "width", card.width - 16)
            verify(editor.width <= view.width)
            verify(editor.lineCount > 1 || size === 500)
            verify(view.height <= 90)
            verify(view.y + view.height <= card.height)
        }
    }
    function test_dragSelectionIsVisibleAndOutsideClickClearsIt() {
        var editor = findChild(card, "commandPayloadEditor")
        card.payload = "AT+RST"
        wait(20)
        mouseDrag(editor, 4, 10, 30, 0)
        verify(editor.selectedText.length > 0)
        compare(editor.selectionColor, cardTheme.primary)
        verify(cardTheme.contrast(editor.selectionColor, editor.selectedTextColor) >= 4.5)
        mouseClick(testCase, 480, 420)
        compare(editor.selectedText, "")
    }
    function test_actionsKeepPayloadAndLoopModeIndependent() {
        var send = findChild(card, "commandSend")
        mouseClick(send, send.width / 2, send.height / 2)
        compare(sendSpy.count, 1)
        compare(sendSpy.signalArguments[0][0], card.payload)
        compare(sendSpy.signalArguments[0][1], false)
        var loop = findChild(card, "loopSelection")
        mouseClick(loop, loop.width / 2, loop.height / 2)
        compare(card.loopSelected, true)
        var more = findChild(card, "commandMore")
        mouseClick(more, more.width / 2, more.height / 2)
        tryCompare(findChild(card, "commandActionsPopup"), "opened", true)
        var format = findChild(card, "commandFormat")
        mouseClick(format, format.width / 2, format.height / 2)
        compare(card.hexMode, true)
        compare(card.loopSelected, true)
        mouseClick(more, more.width / 2, more.height / 2)
        tryCompare(findChild(card, "commandActionsPopup"), "opened", true)
        var remove = findChild(card, "commandDelete")
        mouseClick(remove, remove.width / 2, remove.height / 2)
        compare(deleteSpy.count, 1)
    }
    function test_editsCommitWhenFocusLeaves() {
        var editor = findChild(card, "commandPayloadEditor")
        mouseClick(editor, 20, 10)
        editor.remove(0, editor.length)
        editor.insert(0, "AT+RST")
        mouseClick(testCase, 480, 420)
        tryCompare(card, "payload", "AT+RST")
        compare(editSpy.count, 1)
    }
    function test_moreTogglesAndMenuFitsItsContent() {
        var more = findChild(card, "commandMore")
        var popup = findChild(card, "commandActionsPopup")
        mouseClick(more, more.width / 2, more.height / 2)
        tryCompare(popup, "opened", true)
        var send = findChild(card, "commandMenuSend")
        var format = findChild(card, "commandFormat")
        var remove = findChild(card, "commandDelete")
        compare(popup.width, Math.max(send.implicitWidth, format.implicitWidth, remove.implicitWidth) + popup.leftPadding + popup.rightPadding)
        verify(popup.width < 156)
        compare(findChild(card, "commandMenuSelect"), null)
        mouseClick(more, more.width / 2, more.height / 2)
        tryCompare(popup, "opened", false)
        mouseClick(more, more.width / 2, more.height / 2)
        tryCompare(popup, "opened", true)
        mouseClick(testCase, 480, 420)
        tryCompare(popup, "opened", false)
    }
    function test_editThenSendSurvivesStoreRefresh() {
        var fixture = createTemporaryObject(refreshingStoreFixture, testCase)
        verify(fixture)
        var editor = findChild(fixture, "commandPayloadEditor")
        mouseClick(editor, 15, 10)
        editor.insert(editor.length, "+RST")
        var send = findChild(fixture, "commandSend")
        mouseClick(send, send.width / 2, send.height / 2)
        compare(fixture.sentCount, 1)
        compare(fixture.sentPayload, "AT+RST")
    }
}
