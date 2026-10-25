import QtQuick
import QtQuick.Controls
import QtTest
import "../.." as App

TestCase {
    id: testCase
    name: "DividerInteraction"
    width: 640; height: 500
    visible: true
    when: windowShown
    property real panelWidth: 260
    property real bottomHeight: 150
    App.PanelDivider {
        id: side
        x: testCase.panelWidth; y: 20; width: 12; height: 180
        property real initialWidth: 0
        onResizeStarted: initialWidth = testCase.panelWidth
        onResizeMoved: (delta) => testCase.panelWidth = initialWidth + delta
    }
    App.PanelDivider {
        id: horizontal
        x: 360; y: testCase.height - testCase.bottomHeight - height
        width: 240; height: 15
        vertical: false
        property real initialHeight: 0
        onResizeStarted: initialHeight = testCase.bottomHeight
        onResizeMoved: (delta) => testCase.bottomHeight = Math.max(100, Math.min(250, initialHeight - delta))
    }
    TextField {
        id: editor
        x: 20; y: 400; width: 200; height: 32
        text: "selected command"
        selectByMouse: true
    }
    App.FocusDismissLayer { focusRoot: testCase }

    function init() { failOnWarning(/.*/) }
    function cleanup() {
        testCase.panelWidth = 260
        testCase.bottomHeight = 150
        testCase.forceActiveFocus()
        mouseMove(testCase, 5, 5)
    }
    function test_overlayPreservesDividerHoverAndCursors() {
        mouseMove(side, 6, 50)
        compare(side.containsMouse, true)
        compare(side.cursorShape, Qt.SizeHorCursor)
        var mark = findChild(side, "dividerHighlight")
        tryVerify(() => mark.opacity > 0.4)
        mouseMove(horizontal, 50, 7)
        compare(horizontal.containsMouse, true)
        compare(horizontal.cursorShape, Qt.SizeVerCursor)
        tryVerify(() => findChild(horizontal, "dividerHighlight").opacity > 0.4)
    }
    function test_horizontalDragUsesFixedCoordinatesAsHandleMoves() {
        mousePress(side, 6, 50)
        mouseMove(testCase, 326, 70, 20)
        compare(testCase.panelWidth, 320)
        mouseMove(testCase, 336, 70, 20)
        compare(testCase.panelWidth, 330)
        mouseMove(testCase, 346, 70, 20)
        compare(testCase.panelWidth, 340)
        mouseRelease(testCase, 346, 70)
    }
    function test_verticalDragIsStableAndClampsBothEnds() {
        var y = horizontal.y + 7
        mousePress(horizontal, 50, 7)
        mouseMove(testCase, 410, y - 20, 20)
        compare(testCase.bottomHeight, 170)
        mouseMove(testCase, 410, y - 30, 20)
        compare(testCase.bottomHeight, 180)
        mouseMove(testCase, 410, y - 150, 20)
        compare(testCase.bottomHeight, 250)
        mouseMove(testCase, 410, y + 100, 20)
        compare(testCase.bottomHeight, 100)
        mouseRelease(testCase, 410, y + 100)
    }
    function test_passiveFocusObserverClearsSelectionWithoutBlockingEditor() {
        mouseClick(editor, 50, 16)
        verify(editor.activeFocus)
        editor.selectAll()
        compare(editor.selectedText, "selected command")
        mouseClick(testCase, 600, 450)
        compare(editor.selectedText, "")
        compare(editor.activeFocus, false)
        mouseClick(editor, 50, 16)
        verify(editor.activeFocus)
    }
}
