import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    App.SidebarResizeController {
        id: sidebarResize
        edgeHoldDuration: 60
        onWidthRequested: (width) => testCase.sidebarWidth = width
    }
    property real sidebarWidth: 260
    RowLayout {
        x: 20; y: 220; width: 600; height: 100
        spacing: 0
        Item {
            Layout.preferredWidth: sidebarResize.collapsed ? 0 : testCase.sidebarWidth
            Layout.minimumWidth: Layout.preferredWidth
            Layout.maximumWidth: Layout.preferredWidth
            Layout.fillHeight: true
        }
        App.PanelDivider {
            id: persistentSide
            Layout.preferredWidth: sidebarResize.collapsed && !sidebarResize.active ? 0 : 12
            Layout.fillHeight: true
            visible: !sidebarResize.collapsed || sidebarResize.active
            enabled: !sidebarResize.collapsed || sidebarResize.active
            onResizeStarted: sidebarResize.begin(testCase.sidebarWidth)
            onResizeMoved: (delta) => sidebarResize.move(delta)
            onResizeFinished: sidebarResize.end()
        }
        Item { Layout.fillWidth: true }
    }

    function init() { failOnWarning(/.*/) }
    function cleanup() {
        testCase.panelWidth = 260
        testCase.bottomHeight = 150
        sidebarResize.end()
        sidebarResize.collapsed = false
        testCase.sidebarWidth = 260
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
    function test_sidebarMinimumNeedsHoldAndExtraTravel() {
        sidebarResize.begin(260)
        sidebarResize.move(-80)
        compare(testCase.sidebarWidth, 180)
        wait(90)
        compare(sidebarResize.collapsed, false)
        sidebarResize.move(-100)
        compare(sidebarResize.collapsed, false)
        sidebarResize.move(-130)
        compare(sidebarResize.collapsed, true)
    }
    function test_fastLeftDragWaitsBeforeCollapseAndCanBeCancelled() {
        sidebarResize.begin(260)
        sidebarResize.move(-150)
        compare(sidebarResize.collapsed, false)
        sidebarResize.move(-50)
        wait(90)
        compare(sidebarResize.collapsed, false)
        sidebarResize.move(-150)
        tryCompare(sidebarResize, "collapsed", true)
    }
    function test_collapsedDividerKeepsGrabAndReopensInSameGesture() {
        wait(20)
        mousePress(persistentSide, 6, 50)
        mouseMove(testCase, 130, 270, 20)
        tryCompare(sidebarResize, "collapsed", true)
        compare(persistentSide.pressed, true)
        tryVerify(() => findChild(persistentSide, "dividerHighlight").opacity > 0.8)
        mouseMove(testCase, 326, 270, 20)
        compare(sidebarResize.collapsed, false)
        compare(testCase.sidebarWidth, 300)
        compare(persistentSide.pressed, true)
        mouseRelease(testCase, 326, 270)
        compare(sidebarResize.active, false)
    }
    function test_releaseCancelsPendingCollapse() {
        sidebarResize.begin(260)
        sidebarResize.move(-150)
        sidebarResize.end()
        wait(90)
        compare(sidebarResize.collapsed, false)
    }
}
