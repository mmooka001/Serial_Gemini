import QtQuick
import QtQuick.Layouts
import QtTest
import "../.." as App

TestCase {
    id: testCase
    name: "CommandReorder"
    width: 640; height: 540
    visible: true
    when: windowShown
    property var commands: []
    property var selected: ({})
    property int sentCount: 0
    property int deleteCount: 0
    App.AppTheme { id: testTheme }
    Flickable {
        id: view
        x: 20; y: 20; width: 280; height: 400
        contentHeight: column.height
        interactive: !reorder.active
        clip: true
        ColumnLayout {
            id: column
            width: view.width
            spacing: 6
            Repeater {
                id: entries
                model: testCase.commands
                App.CommandCard {
                    id: entry
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    theme: testTheme
                    scrollContainer: view
                    commandName: modelData.name
                    payload: modelData.payload
                    hexMode: modelData.hex || false
                    loopSelected: testCase.selected["0:" + index] === true
                    onSendRequested: testCase.sentCount++
                    onDeleteRequested: testCase.deleteCount++
                    onLoopToggled: loopSelected = !loopSelected
                    onFormatToggled: hexMode = !hexMode
                    onReorderStarted: (position) => reorder.begin(0, index, column, entries, entry, position)
                    onReorderMoved: (position) => reorder.move(position)
                    onReorderFinished: (position, name, payload) => reorder.finish(position, name, payload)
                    onReorderCanceled: reorder.cancel()
                }
            }
        }
    }
    App.CommandReorderController {
        id: reorder
        surface: testCase
        view: view
        onMoveRequested: (group, from, to, name, payload) => {
            testCase.selected = remapSelection(testCase.selected, group, from, to)
            var items = testCase.commands.slice()
            var moved = items.splice(from, 1)[0]
            moved.name = name
            moved.payload = payload
            items.splice(to, 0, moved)
            testCase.commands = items
        }
    }
    App.FocusDismissLayer { focusRoot: testCase }
    function init() {
        failOnWarning(/.*/)
        testCase.commands = [{name: "A", payload: "A_PAYLOAD"}, {name: "B", payload: "B_PAYLOAD"}, {name: "C", payload: "C_PAYLOAD"}]
        testCase.selected = {"0:0": true, "0:2": true, "1:0": true}
        view.contentY = 0
        view.height = 400
        tryCompare(entries, "count", 3)
        tryVerify(() => entries.itemAt(2).height > 50 && entries.itemAt(2).y > entries.itemAt(1).y)
    }
    function cleanup() {
        reorder.cancel()
        testCase.forceActiveFocus()
        testCase.sentCount = 0
        testCase.deleteCount = 0
    }
    function test_nameFocusPillAndCheckboxAreAligned() {
        var entry = entries.itemAt(0)
        var name = findChild(entry, "commandNameEditor")
        var check = findChild(entry, "loopSelection")
        compare(name.mapToItem(entry, 0, name.height / 2).y, check.mapToItem(entry, 0, check.height / 2).y)
        mouseClick(name, name.width / 2, name.height / 2)
        verify(name.activeFocus)
        compare(name.background.radius, 8)
        verify(name.background.color.a > 0.9)
    }
    function test_directModeToggleDoesNotOpenPopup() {
        var entry = entries.itemAt(0)
        var toggle = findChild(entry, "commandFormatToggle")
        mouseClick(toggle, toggle.width / 2, toggle.height / 2)
        compare(entry.hexMode, true)
        compare(findChild(entry, "commandActionsPopup").opened, false)
    }
    function test_rightClickPayloadHasSendModeAndDeleteActions() {
        var entry = entries.itemAt(0)
        var editor = findChild(entry, "commandPayloadEditor")
        var popup = findChild(entry, "commandActionsPopup")
        mouseClick(editor, 15, 12, Qt.RightButton)
        tryCompare(popup, "opened", true)
        var send = findChild(entry, "commandMenuSend")
        mouseClick(send, send.width / 2, send.height / 2)
        compare(testCase.sentCount, 1)
        compare(findChild(entry, "commandMenuSelect"), null)
        mouseClick(editor, 15, 12, Qt.RightButton)
        tryCompare(popup, "opened", true)
        var remove = findChild(entry, "commandDelete")
        mouseClick(remove, remove.width / 2, remove.height / 2)
        compare(testCase.deleteCount, 1)
    }
    function test_longHoldReordersAndSelectionFollowsCommand() {
        var first = entries.itemAt(0)
        var editor = findChild(first, "commandPayloadEditor")
        editor.forceActiveFocus()
        editor.insert(editor.length, "_EDITED")
        mousePress(editor, 15, 12)
        tryCompare(first, "reorderHeld", true)
        verify(reorder.active)
        var last = entries.itemAt(2)
        var end = last.mapToItem(testCase, 20, last.height - 4)
        mouseMove(testCase, end.x, end.y, 20)
        compare(reorder.targetIndex, 2)
        mouseRelease(testCase, end.x, end.y)
        compare(testCase.commands[0].name, "B")
        compare(testCase.commands[2].name, "A")
        compare(testCase.commands[2].payload, "A_PAYLOAD_EDITED")
        compare(testCase.selected["0:2"], true)
        compare(testCase.selected["0:1"], true)
        compare(testCase.selected["0:0"], undefined)
        compare(testCase.selected["1:0"], true)
        compare(reorder.active, false)
    }
    function test_ordinaryTextDragDoesNotArmReorder() {
        var first = entries.itemAt(0)
        var editor = findChild(first, "commandPayloadEditor")
        mousePress(editor, 4, 12)
        mouseMove(editor, 50, 12, 20)
        wait(520)
        compare(first.reorderHeld, false)
        verify(editor.selectedText.length > 0)
        mouseRelease(editor, 50, 12)
        compare(testCase.commands[0].name, "A")
    }
    function test_escapeCancelsReorder() {
        var first = entries.itemAt(0)
        var editor = findChild(first, "commandPayloadEditor")
        mousePress(editor, 15, 12)
        tryCompare(first, "reorderHeld", true)
        keyClick(Qt.Key_Escape)
        compare(reorder.active, false)
        mouseRelease(editor, 15, 12)
        compare(testCase.commands[0].name, "A")
    }
    function test_reorderScrollsAtViewportEdge() {
        view.height = 160
        var first = entries.itemAt(0)
        var editor = findChild(first, "commandPayloadEditor")
        mousePress(editor, 15, 12)
        tryCompare(first, "reorderHeld", true)
        mouseMove(testCase, 100, 195, 20)
        tryVerify(() => view.contentY > 0)
        keyClick(Qt.Key_Escape)
        mouseRelease(testCase, 100, 195)
    }
    function test_scrollingDismissesMenuWithoutMovingItsAnchor() {
        view.height = 160
        var first = entries.itemAt(0)
        var editor = findChild(first, "commandPayloadEditor")
        mouseClick(editor, 15, 12, Qt.RightButton)
        var popup = findChild(first, "commandActionsPopup")
        tryCompare(popup, "opened", true)
        var origin = Qt.point(popup.x, popup.y)
        mouseWheel(view, 150, 100, 0, -120)
        tryCompare(popup, "visible", false)
        view.contentY = 40
        compare(Qt.point(popup.x, popup.y), origin)
    }
}
