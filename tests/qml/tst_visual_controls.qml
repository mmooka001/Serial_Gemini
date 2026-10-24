import QtQuick
import QtTest
import "../.." as App

TestCase {
    id: testCase
    name: "VisualControls"
    width: 420
    height: 160
    visible: true
    when: windowShown

    App.AppTheme { id: theme }
    App.SegmentedControl {
        id: modes
        x: 20; y: 20; width: 160; height: 32
        theme: theme
        model: ["TXT", "HEX"]
        onActivated: (index) => currentIndex = index
    }
    App.ActionButton {
        id: toggle
        x: 220; y: 20
        theme: theme
        text: "锁定"
        onClicked: selected = !selected
    }
    SignalSpy { id: modeSpy; target: modes; signalName: "activated" }

    function initTestCase() { failOnWarning(/.*/) }
    function cleanup() {
        theme.mode = 4
        theme.style = 2
        modes.currentIndex = 0
        toggle.selected = false
        modeSpy.clear()
    }
    function contrast(first, second) {
        var a = theme.luminance(first)
        var b = theme.luminance(second)
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
    }
    function test_allSchemesHaveReadableControls() {
        for (var mode = 0; mode < 6; ++mode) {
            for (var style = 0; style < 4; ++style) {
                theme.mode = mode
                theme.style = style
                var label = "mode " + mode + ", style " + style
                verify(contrast(theme.primary, theme.primaryText) >= 4.5, "Primary label: " + label + " " + theme.primary + " / " + theme.primaryText + " ratio " + contrast(theme.primary, theme.primaryText))
                verify(contrast(theme.secondary, theme.surface) >= 4.5, "Secondary label: " + label)
                verify(contrast(theme.text, theme.block) >= 7, "Input label: " + label)
            }
        }
    }
    function test_statusDoesNotChangeWithAccent() {
        var success = theme.success.toString()
        var danger = theme.danger.toString()
        for (var mode = 0; mode < 5; ++mode) {
            for (var style = 0; style < 4; ++style) {
                theme.mode = mode
                theme.style = style
                compare(theme.success.toString(), success)
                compare(theme.danger.toString(), danger)
            }
        }
    }
    function test_segmentCommitsOnClickAndTracksExternalState() {
        mouseMove(modes, 120, 16)
        compare(modes.currentIndex, 0)
        mouseClick(modes, 120, 16)
        compare(modeSpy.count, 1)
        compare(modes.currentIndex, 1)
        modes.currentIndex = 0
        mouseClick(modes, 120, 16)
        compare(modeSpy.count, 2)
        compare(modes.currentIndex, 1)
    }
    function test_toggleSupportsKeyboardAndDisabledState() {
        toggle.forceActiveFocus()
        keyClick(Qt.Key_Space)
        compare(toggle.selected, true)
        toggle.enabled = false
        mouseClick(toggle, toggle.width / 2, toggle.height / 2)
        compare(toggle.selected, true)
        toggle.enabled = true
        mouseClick(toggle, toggle.width / 2, toggle.height / 2)
        compare(toggle.selected, false)
    }
}
