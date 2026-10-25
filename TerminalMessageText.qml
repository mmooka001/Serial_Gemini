import QtQuick

Item {
    id: message
    required property AppTheme theme
    property string text: ""
    property real maximumWidth: 500
    property bool expanded: false
    readonly property bool truncated: measure.truncated
    readonly property string selectedText: editor.selectedText
    implicitWidth: measure.width
    implicitHeight: expanded ? editor.contentHeight : Math.min(editor.contentHeight, measure.height)
    clip: true

    Text {
        id: measure
        visible: false
        text: message.text
        textFormat: Text.PlainText
        font.family: "Consolas"
        font.pixelSize: 13
        width: Math.min(implicitWidth, message.maximumWidth)
        topPadding: 2; bottomPadding: 2
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
    }
    TextEdit {
        id: editor
        objectName: "terminalTextEditor"
        anchors.fill: parent
        text: message.text
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
