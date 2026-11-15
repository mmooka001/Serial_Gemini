import QtQuick

Item {
    id: message
    required property AppTheme theme
    property string text: ""
    property real maximumWidth: 500
    property bool expanded: false
    property bool hexMode: false
    property string encoding: "UTF-8"
    property int textSize: 13
    property int page: 0
    readonly property int pageSize: 4095
    readonly property bool paged: text.length > 2 * pageSize
    readonly property int pageCount: paged ? Math.ceil(text.length / pageSize) : 1
    readonly property bool truncated: text.length > preview.length || measure.truncated
    readonly property string preview: text.slice(0, characterBoundary(510))
    readonly property string selectedText: editor.selectedText
    onTextChanged: page = 0
    onExpandedChanged: page = 0

    function characterBoundary(index: int): int {
        const code = text.charCodeAt(index)
        return index > 0 && code >= 0xdc00 && code <= 0xdfff ? index - 1 : index
    }

    implicitWidth: expanded && paged ? maximumWidth : measure.width
    implicitHeight: expanded ? editor.contentHeight : Math.min(editor.contentHeight, measure.height)
    clip: true

    Text {
        id: measure
        visible: false
        text: message.preview
        textFormat: Text.PlainText
        font.family: "Consolas"
        font.pixelSize: message.textSize
        width: Math.min(implicitWidth, message.maximumWidth)
        topPadding: 2; bottomPadding: 2
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
    }
    TextEdit {
        id: editor
        objectName: "terminalTextEditor"
        readonly property bool countsBytes: true
        readonly property bool countsHexBytes: message.hexMode
        readonly property bool spacedHexBytes: true
        readonly property string byteEncoding: message.encoding
        anchors.fill: parent
        text: !message.expanded ? message.preview
              : !message.paged ? message.text
              : message.text.slice(message.characterBoundary(message.page * message.pageSize),
                                   message.characterBoundary((message.page + 1) * message.pageSize))
        textFormat: TextEdit.PlainText
        font: measure.font
        color: message.theme.text
        topPadding: 2; bottomPadding: 2
        wrapMode: TextEdit.Wrap
        readOnly: true
        selectByMouse: true
        selectByKeyboard: true
        persistentSelection: false
        selectionColor: message.theme.primary
        selectedTextColor: message.theme.primaryText
        Accessible.name: "终端消息"
    }
}
