import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: workspace
    objectName: "compareWorkspace"
    required property AppTheme theme
    required property string textA
    required property string textB
    property int textSize: 14
    property string summary: ""
    property var changes: []
    property string displayedA: ""
    readonly property string removedBackground: theme.blend(theme.block, theme.danger, theme.dark ? 0.28 : 0.22).toString()
    readonly property string addedBackground: theme.blend(theme.block, theme.success, theme.dark ? 0.28 : 0.22).toString()
    readonly property var rendered: renderResult()
    readonly property int maxInputLength: 64 * 1024
    color: theme.surface
    radius: 14
    border.color: theme.line

    function tokenize(source) {
        const values = []
        const offsets = []
        let offset = 0
        for (const character of source) {
            offsets.push(offset)
            values.push(character)
            offset += character.length
        }
        offsets.push(offset)
        return { values: values, offsets: offsets }
    }

    // Find a nearby shared run so an insertion does not mark the rest of the input as changed.
    function nextMatch(a, b, i, j) {
        const positions = new Map()
        const lookahead = 48
        const run = Math.min(3, a.length - i, b.length - j)
        if (run < 1) return null
        for (let offset = 0; offset <= lookahead && j + offset + run <= b.length; ++offset) {
            const key = b.slice(j + offset, j + offset + run).join("\u0000")
            if (!positions.has(key)) positions.set(key, offset)
        }
        let best = null
        for (let offset = 0; offset <= lookahead && i + offset + run <= a.length; ++offset) {
            const key = a.slice(i + offset, i + offset + run).join("\u0000")
            const other = positions.get(key)
            if (other === undefined || offset + other === 0) continue
            if (!best || offset + other < best[0] + best[1])
                best = [offset, other]
        }
        return best
    }

    function compare() {
        displayedA = textA
        changes = []
        if (textA.length > maxInputLength || textB.length > maxInputLength) {
            summary = "单侧输入上限为 65,536 个 UTF-16 代码单元"
            return
        }
        if (!textA.length && !textB.length) {
            summary = "差异将显示在这里"
            return
        }

        const a = tokenize(textA)
        const b = tokenize(textB)
        let i = 0
        let j = 0
        while (i < a.values.length && i < b.values.length && a.values[i] === b.values[i]) ++i
        j = i

        // Keep a shared suffix aligned even when an inserted block exceeds the lookahead.
        let endA = a.values.length
        let endB = b.values.length
        while (endA > i && endB > j && a.values[endA - 1] === b.values[endB - 1]) {
            --endA
            --endB
        }
        const valuesA = a.values.slice(0, endA)
        const valuesB = b.values.slice(0, endB)
        const rows = []
        let retryMatchAt = 0
        while (i < endA || j < endB) {
            if (i < endA && j < endB && a.values[i] === b.values[j]) {
                ++i
                ++j
                continue
            }
            const canAlign = i + j >= retryMatchAt
            const match = canAlign ? nextMatch(valuesA, valuesB, i, j) : null
            if (canAlign && !match) retryMatchAt = i + j + 48
            const da = match ? match[0] : (j >= endB ? endA - i : Math.min(1, endA - i))
            const db = match ? match[1] : (i >= endA ? endB - j : Math.min(1, endB - j))
            const previous = rows[rows.length - 1]
            if (previous && previous.aEnd === i && previous.bEnd === j) {
                previous.aEnd += da
                previous.bEnd += db
            } else {
                rows.push({ aStart: i, aEnd: i + da, bStart: j, bEnd: j + db })
            }
            i += da
            j += db
        }
        changes = rows.slice(0, 1000).map(row => ({
            start: a.offsets[row.aStart],
            end: a.offsets[row.aEnd],
            addedText: textB.slice(b.offsets[row.bStart], b.offsets[row.bEnd])
        }))
        summary = rows.length === 0 ? "两份内容一致" : rows.length + " 处差异"
                  + (rows.length > 1000 ? " · 显示前 1000 处" : "")
    }

    onTextAChanged: compareTimer.restart()
    onTextBChanged: compareTimer.restart()
    Component.onCompleted: compareTimer.restart()
    Timer {
        id: compareTimer
        interval: 100
        onTriggered: workspace.compare()
    }

    function escapeHtml(value: string): string {
        return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
                    .replace(/\n/g, "<br/>")
    }

    function renderResult() {
        const source = displayedA
        const fragments = ['<pre style="margin:0; white-space:pre-wrap">']
        const marks = []
        let documentPosition = 0
        function append(value, background, added) {
            if (!value.length) return
            if (background) {
                // Make changes that consist solely of line breaks visible.
                value = value.replace(/\n/g, "↵\n")
                marks.push({ start: documentPosition, end: documentPosition + value.length, added: added })
                fragments.push('<span style="background-color:' + background + '">'
                               + escapeHtml(value) + '</span>')
            } else {
                fragments.push(escapeHtml(value))
            }
            documentPosition += value.length
        }

        // Walk A once. Insert B's snippets after the affected A line, without splitting that line.
        let offset = 0
        let redIndex = 0
        function appendOriginal(until) {
            while (redIndex < changes.length && changes[redIndex].start < until) {
                const change = changes[redIndex]
                append(source.slice(offset, change.start))
                const end = Math.min(until, change.end)
                append(source.slice(Math.max(offset, change.start), end), removedBackground, false)
                offset = end
                if (change.end > until) return
                ++redIndex
            }
            append(source.slice(offset, until))
            offset = until
        }
        for (const change of changes) {
            if (!change.addedText.length) continue
            const lineBreak = source.indexOf("\n", change.end)
            appendOriginal(lineBreak < 0 ? source.length : lineBreak)
            if (source.length || documentPosition) append("\n")
            append(change.addedText, addedBackground, true)
        }
        appendOriginal(source.length)
        fragments.push("</pre>")
        return { html: fragments.join(""), marks: marks }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "比对结果"
                color: workspace.theme.text
                font.pixelSize: workspace.theme.uiPixels(15)
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                Layout.maximumWidth: workspace.width / 2
                text: workspace.summary
                color: workspace.theme.secondary
                font.pixelSize: workspace.theme.uiPixels(11)
                elide: Text.ElideRight
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 3
            ScrollView {
                id: resultView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                padding: 0
                rightPadding: resultScrollBar.width + 3
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical: SlimScrollBar {
                    id: resultScrollBar
                    objectName: "compareResultScrollBar"
                    parent: resultView
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    theme: workspace.theme
                    policy: ScrollBar.AlwaysOn
                    interactive: true
                    opacity: 1
                }
                TextArea {
                    id: resultText
                    objectName: "compareResultText"
                    readonly property bool countsBytes: true
                    readonly property bool countsHexBytes: false
                    readonly property string selectedByteText: selectedText.replace(/[\u2028\u2029]/g, "\n")
                    text: workspace.rendered.html
                    textFormat: TextEdit.RichText
                    font.family: "Consolas"
                    font.pixelSize: workspace.textSize
                    color: workspace.theme.text
                    wrapMode: TextEdit.Wrap
                    readOnly: true
                    selectByMouse: true
                    selectionColor: workspace.theme.primary
                    selectedTextColor: workspace.theme.primaryText
                    padding: 0
                    background: null
                    onContentHeightChanged: overviewRefresh.restart()
                    onWidthChanged: overviewRefresh.restart()
                    onTextChanged: overviewRefresh.restart()
                }
            }
            Canvas {
                id: overview
                property var markers: []
                Layout.preferredWidth: 8
                Layout.fillHeight: true
                onWidthChanged: overviewRefresh.restart()
                onHeightChanged: overviewRefresh.restart()
                onVisibleChanged: if (visible) overviewRefresh.restart()
                Timer {
                    id: overviewRefresh
                    interval: 80
                    onTriggered: {
                        if (!overview.visible) return
                        const documentHeight = Math.max(1, resultView.height, resultText.contentHeight)
                        overview.markers = workspace.rendered.marks.map(mark => {
                            const first = resultText.positionToRectangle(mark.start)
                            const last = resultText.positionToRectangle(mark.end - 1)
                            return { top: first.y / documentHeight,
                                     bottom: (last.y + last.height) / documentHeight,
                                     added: mark.added }
                        })
                        overview.requestPaint()
                    }
                }
                Connections {
                    target: workspace
                    function onRenderedChanged() { overviewRefresh.restart() }
                    function onTextSizeChanged() { overviewRefresh.restart() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const laneWidth = (width - 1) / 2
                    for (const mark of markers) {
                        const top = Math.min(Math.max(0, height - 2), mark.top * height)
                        const bottom = Math.min(height, mark.bottom * height)
                        ctx.fillStyle = mark.added ? workspace.theme.success : workspace.theme.danger
                        ctx.fillRect(mark.added ? laneWidth + 1 : 0, top, laneWidth, Math.max(2, bottom - top))
                    }
                }
            }
        }
    }
}
