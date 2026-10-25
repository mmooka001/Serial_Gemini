import QtQuick
import QtTest
import "../.." as App

TestCase {
    id: testCase
    name: "VisualControls"
    width: 420
    height: 360
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
    App.AccentColorPicker {
        id: picker
        x: 20; y: 100; width: 260
        theme: theme
        onColorEdited: (color) => selectedColor = color
    }
    SignalSpy { id: colorSpy; target: picker; signalName: "colorEdited" }

    function init() { failOnWarning(/.*/) }
    function cleanup() {
        theme.mode = 4
        theme.style = 2
        theme.appearance = 0
        theme.customAccentEnabled = false
        theme.systemDark = false
        modes.currentIndex = 0
        toggle.selected = false
        modeSpy.clear()
        colorSpy.clear()
    }
    function contrast(first, second) {
        var a = theme.luminance(first)
        var b = theme.luminance(second)
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
    }
    function test_allSchemesHaveReadableControls() {
        for (var appearance = 0; appearance < 2; ++appearance) {
          theme.appearance = appearance
          for (var mode = 0; mode < 6; ++mode) {
            for (var style = 0; style < 4; ++style) {
                theme.mode = mode
                theme.style = style
                var label = "mode " + mode + ", style " + style
                verify(contrast(theme.primary, theme.primaryText) >= 4.5, "Primary label: " + label + " " + theme.primary + " / " + theme.primaryText + " ratio " + contrast(theme.primary, theme.primaryText))
                verify(contrast(theme.secondary, theme.surface) >= 4.5, "Secondary label: " + label)
                verify(contrast(theme.text, theme.block) >= 7, "Input label: " + label)
                verify(contrast(theme.primary, theme.surface) >= 3, "Accent mark: " + label)
            }
          }
        }
    }
    function test_systemAppearanceTracksChangesAndManualModeOverrides() {
        theme.appearance = 2
        theme.systemDark = true
        compare(theme.dark, true)
        theme.systemDark = false
        compare(theme.dark, false)
        theme.appearance = 0
        compare(theme.dark, true)
        theme.appearance = 1
        theme.systemDark = true
        compare(theme.dark, false)
    }
    function test_customExtremesStayReadable() {
        theme.customAccentEnabled = true
        var colors = ["#000000", "#ffffff", "#ff0000", "#00ff00", "#0000ff", "#777777"]
        for (var appearance = 0; appearance < 2; ++appearance) {
            theme.appearance = appearance
            for (var style = 0; style < 4; ++style) {
                theme.style = style
                for (var color of colors) {
                    theme.customAccent = color
                    verify(contrast(theme.primary, theme.primaryText) >= 4.5, "Custom primary label " + color)
                    verify(contrast(theme.primary, theme.surface) >= 3, "Custom accent " + color)
                    verify(contrast(theme.secondary, theme.surface) >= 4.5, "Custom secondary label " + color)
                }
            }
        }
    }
    function test_hexEntryNormalizesAndAppliesColor() {
        var field = findChild(picker, "hexField")
        verify(field !== null)
        field.forceActiveFocus()
        field.selectAll()
        field.remove(0, field.length)
        field.insert(0, "#f80")
        keyClick(Qt.Key_Return)
        compare(picker.selectedColor.toString(), "#ff8800")
        verify(colorSpy.count > 0)
        compare(picker.normalizeHex("336699"), "#336699")
        compare(picker.normalizeHex("#badhex"), "")
        compare(picker.normalizeHex("#12345678"), "")
    }
    function test_spectrumDragUpdatesActualColor() {
        picker.selectedColor = "#ff0000"
        mousePress(picker, 30, 20)
        mouseMove(picker, 180, 70, 30)
        mouseRelease(picker, 180, 70)
        verify(colorSpy.count >= 2)
        verify(Math.abs(picker.selectedColor.hsvSaturation - 180 / 260) < 0.02)
        verify(Math.abs(picker.selectedColor.hsvValue - (1 - 70 / 132)) < 0.02)
    }
    function test_incompleteHexKeepsPreviousColor() {
        picker.selectedColor = "#336699"
        var field = findChild(picker, "hexField")
        field.forceActiveFocus()
        field.remove(0, field.length)
        field.insert(0, "#12")
        verify(!field.acceptableInput)
        toggle.forceActiveFocus()
        compare(picker.selectedColor.toString(), "#336699")
        compare(field.text, "#336699")
        compare(colorSpy.count, 0)
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
    function test_selectedSegmentCannotToggleItselfOff() {
        var first = findChild(modes, "segment0")
        var second = findChild(modes, "segment1")
        mouseClick(modes, 40, 16)
        mouseClick(modes, 40, 16)
        compare(modes.currentIndex, 0)
        compare(first.selected, true)
        compare(second.selected, false)
        modes.currentIndex = 1
        compare(first.selected, false)
        compare(second.selected, true)
    }
}
