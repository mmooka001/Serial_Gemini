import QtQuick
import QtTest
import "../.." as App

TestCase {
    id: testCase
    name: "TerminalSelection"
    width: 500; height: 420
    visible: true
    when: windowShown
    App.AppTheme { id: theme }
    App.TerminalMessageText {
        id: message
        x: 20; y: 20
        theme: theme
        maximumWidth: 220
        text: "SERIAL COPY 012345"
    }
    TextEdit { id: pasteTarget; x: 20; y: 300; width: 300; height: 40 }
    App.FocusDismissLayer { focusRoot: testCase }
    function init() { failOnWarning(/.*/) }
    function cleanup() {
        testCase.forceActiveFocus()
        message.text = "SERIAL COPY 012345"
        message.maximumWidth = 220
        message.expanded = false
        pasteTarget.text = ""
    }
    function test_dragSelectionCanCopyAndOutsideClearsSelection() {
        var editor = findChild(message, "terminalTextEditor")
        tryVerify(() => editor.width > 50 && editor.height > 10)
        mouseDrag(editor, 4, 10, 70, 0)
        verify(editor.selectedText.length > 0)
        var selected = editor.selectedText
        keyClick(Qt.Key_C, Qt.ControlModifier)
        pasteTarget.forceActiveFocus()
        pasteTarget.paste()
        compare(pasteTarget.text, selected)
        mouseClick(editor, 10, 10)
        editor.selectAll()
        mouseClick(testCase, 480, 400)
        compare(editor.selectedText, "")
    }
    function test_terminalTextStaysReadOnlyAndPreservesWhitespace() {
        var editor = findChild(message, "terminalTextEditor")
        var source = "<b>原始文本</b>   \r\n"
        message.text = source
        compare(editor.text, source.replace(/\r\n/g, "\n"))
        compare(editor.textFormat, TextEdit.PlainText)
        mouseClick(editor, 8, 10)
        editor.selectAll()
        keyClick(Qt.Key_X)
        compare(editor.text, source.replace(/\r\n/g, "\n"))
    }
    function test_longTextCanExpandForFullSelection() {
        message.maximumWidth = 160
        message.text = "0123456789 ".repeat(40)
        tryCompare(message, "truncated", true)
        var collapsedHeight = message.height
        verify(collapsedHeight > 0)
        message.expanded = true
        tryVerify(() => message.height > collapsedHeight)
        var editor = findChild(message, "terminalTextEditor")
        editor.selectAll()
        compare(editor.selectedText, message.text)
    }
}
